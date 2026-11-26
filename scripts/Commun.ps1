# Fonctions communes (installation, mise a jour, configuration).
# Utilisable avec : . "$PSScriptRoot\Commun.ps1"

# Dossier d'installation = parent du dossier scripts (choisi a l'installation)
$script:AppDir       = Split-Path -Parent $PSScriptRoot
$script:ConfigDir    = Join-Path $env:APPDATA 'DrSanteOutils'
$script:ConfigFile   = Join-Path $script:ConfigDir 'config.ini'
$script:ShaFile      = Join-Path $script:ConfigDir 'version.sha'
$script:NomTache     = 'Dr Sante outils'   # tache planifiee (demarrage administrateur)
# SECURITE : source des mises a jour figee dans le code (et non lue dans
# config.ini, modifiable sans droits administrateur alors que la mise a jour
# peut s'executer en mode administrateur).
$script:DepotOfficiel   = 'geoffroydg/drsante-outils'
$script:BrancheOfficiel = 'main'
$script:MarqueurPatient = '.dossier_patient_drsante'

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# --- config.ini (UTF-16, lisible aussi par AutoHotkey) ---------------------
function Get-IniValue {
    param([string]$Section, [string]$Key, [string]$Default = '')
    if (-not (Test-Path -LiteralPath $script:ConfigFile)) { return $Default }
    $current = ''
    foreach ($line in (Get-Content -LiteralPath $script:ConfigFile -Encoding Unicode)) {
        $l = $line.Trim()
        if ($l -match '^\[(.+)\]$') { $current = $Matches[1]; continue }
        if ($current -eq $Section -and $l -match '^([^=;#]+)=(.*)$') {
            if ($Matches[1].Trim() -eq $Key) { return $Matches[2].Trim() }
        }
    }
    return $Default
}

function Set-IniValue {
    param([string]$Section, [string]$Key, [string]$Value)
    # SECURITE : une valeur ne peut pas creer de nouvelle ligne / section
    $Value = ($Value -replace '[\r\n]', ' ').Trim()
    if (-not (Test-Path -LiteralPath $script:ConfigDir)) {
        New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null
    }
    $lines = @()
    if (Test-Path -LiteralPath $script:ConfigFile) {
        $lines = @(Get-Content -LiteralPath $script:ConfigFile -Encoding Unicode)
    }
    $out = New-Object System.Collections.Generic.List[string]
    $current = ''; $done = $false; $sectionSeen = $false
    foreach ($line in $lines) {
        $l = $line.Trim()
        if ($l -match '^\[(.+)\]$') {
            if ($current -eq $Section -and -not $done) { $out.Add("$Key=$Value"); $done = $true }
            $current = $Matches[1]
            if ($current -eq $Section) { $sectionSeen = $true }
            $out.Add($line); continue
        }
        if ($current -eq $Section -and $l -match '^([^=;#]+)=' -and $Matches[1].Trim() -eq $Key) {
            $out.Add("$Key=$Value"); $done = $true; continue
        }
        $out.Add($line)
    }
    if (-not $done) {
        if (-not $sectionSeen) { $out.Add("[$Section]") }
        $out.Add("$Key=$Value")
    }
    Set-Content -LiteralPath $script:ConfigFile -Value $out -Encoding Unicode
}

# --- Jeton de lecture (depot prive) : chiffre pour CE compte Windows -------
function Save-Token {
    param([string]$Token)
    if ([string]::IsNullOrWhiteSpace($Token)) { return }
    $secure = ConvertTo-SecureString $Token -AsPlainText -Force
    Set-IniValue 'depot' 'token_dpapi' (ConvertFrom-SecureString $secure)
}

function Get-Token {
    $enc = Get-IniValue 'depot' 'token_dpapi' ''
    if (-not $enc) { return '' }
    try {
        $secure = ConvertTo-SecureString $enc
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    } catch { return '' }
}

function Get-GitHubHeaders {
    param([string]$Accept = 'application/vnd.github+json')
    $h = @{ 'User-Agent' = 'DrSanteOutils'; 'Accept' = $Accept }
    $t = Get-Token
    if ($t) { $h['Authorization'] = "Bearer $t" }
    return $h
}

# --- Depot GitHub -----------------------------------------------------------
function Get-RemoteSha {
    $depot  = $script:DepotOfficiel
    $branch = $script:BrancheOfficiel
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 `
        -Uri "https://api.github.com/repos/$depot/commits/$branch" `
        -Headers (Get-GitHubHeaders 'application/vnd.github.sha')
    $c = $r.Content
    if ($c -is [byte[]]) { $c = [Text.Encoding]::ASCII.GetString($c) }
    $c = ([string]$c).Trim()
    if ($c -notmatch '^[0-9a-f]{40}$') { return '' }   # reponse inattendue : on ignore
    return $c
}

# Telecharge le depot (zip) et copie son contenu dans $AppDir (ecrase).
# -Ref : version exacte (empreinte) a installer, celle qui a ete verifiee.
function Install-DepotZip {
    param([string]$Ref = '')
    $depot  = $script:DepotOfficiel
    $branch = $script:BrancheOfficiel
    if ($Ref -match '^[0-9a-f]{40}$') { $branch = $Ref }

    $tmp = Join-Path $env:TEMP ('drsante_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp 'depot.zip'
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 120 -OutFile $zip `
            -Uri "https://api.github.com/repos/$depot/zipball/$branch" `
            -Headers (Get-GitHubHeaders)
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'x') -Force
        $root = Get-ChildItem -LiteralPath (Join-Path $tmp 'x') -Directory | Select-Object -First 1
        if (-not $root) { throw 'Archive du depot vide ou illisible.' }
        # Archive incomplete ou etrangere : on n'installe rien
        foreach ($indispensable in @('scripts\Commun.ps1', 'scripts\DrSante.ahk', 'scripts\Demarrer.ps1', 'prompts\heidi_consultation.txt')) {
            if (-not (Test-Path -LiteralPath (Join-Path $root.FullName $indispensable))) {
                throw "Archive de mise a jour incomplete ($indispensable manquant) : rien n'a ete installe."
            }
        }
        if (-not (Test-Path -LiteralPath $script:AppDir)) {
            New-Item -ItemType Directory -Path $script:AppDir -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $root.FullName '*') -Destination $script:AppDir -Recurse -Force
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Une nouvelle version est-elle publiee ? $null si impossible de verifier.
function Get-UpdateInfo {
    $remote = Get-RemoteSha
    if (-not $remote) { return $null }
    $local = ''
    if (Test-Path -LiteralPath $script:ShaFile) { $local = (Get-Content -LiteralPath $script:ShaFile -Raw).Trim() }
    return [pscustomobject]@{ Disponible = ($remote -ne $local); Remote = $remote }
}

# Installe la version $Remote. Renvoie $true si le prompt Heidi a change.
function Install-Update {
    param([Parameter(Mandatory = $true)][string]$Remote)
    $promptFile = Join-Path $script:AppDir 'prompts\heidi_consultation.txt'
    $before = ''
    if (Test-Path -LiteralPath $promptFile) { $before = (Get-FileHash -LiteralPath $promptFile).Hash }

    Install-DepotZip -Ref $Remote
    if (-not (Test-Path -LiteralPath $script:ConfigDir)) { New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null }
    Set-Content -LiteralPath $script:ShaFile -Value $Remote -Encoding ASCII

    $after = ''
    if (Test-Path -LiteralPath $promptFile) { $after = (Get-FileHash -LiteralPath $promptFile).Hash }
    return ($before -ne $after)
}

# --- AutoHotkey v2 ----------------------------------------------------------
function Get-AhkExe {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey32.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey32.exe')
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    $cmd = Get-Command 'AutoHotkey64.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

# Arrete les processus PowerShell dont la ligne de commande contient $Motif
function Stop-ScriptProcess {
    param([string]$Motif)
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$Motif*" -and $_.ProcessId -ne $PID } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

# --- Prompt Heidi ----------------------------------------------------------
# Texte du prompt adapte a ce poste (bloc etiquette retire si pas d'imprimante)
function Get-HeidiPromptText {
    $src = Join-Path $script:AppDir 'prompts\heidi_consultation.txt'
    if (-not (Test-Path -LiteralPath $src)) { throw 'Prompt Heidi introuvable (installation incomplete).' }
    $avecEtiquette = ((Get-IniValue 'general' 'etiquette' '0') -eq '1')
    $out = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in (Get-Content -LiteralPath $src -Encoding UTF8)) {
        if ($line -match '^#@ETIQUETTE_DEBUT') { if (-not $avecEtiquette) { $skip = $true }; continue }
        if ($line -match '^#@ETIQUETTE_FIN')   { $skip = $false; continue }
        if (-not $skip) { $out.Add($line) }
    }
    return ($out -join "`r`n")
}

# Empreinte courte du prompt (change des que le texte ou la variante change)
function Get-HeidiPromptVersion {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $h = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes((Get-HeidiPromptText))) }
    finally { $sha.Dispose() }
    return ([BitConverter]::ToString($h) -replace '-', '').Substring(0, 8)
}

# Le dernier prompt copie correspond-il aux scripts installes ?
function Test-HeidiPromptAJour {
    return ((Get-IniValue 'heidi' 'prompt_copie' '') -eq (Get-HeidiPromptVersion))
}

# Copie le prompt dans le presse-papiers et note sa version. Renvoie $true si
# la variante "avec etiquette" a ete copiee.
function Copy-HeidiPrompt {
    Set-Clipboard -Value (Get-HeidiPromptText)
    Set-IniValue 'heidi' 'prompt_copie' (Get-HeidiPromptVersion)
    return ((Get-IniValue 'general' 'etiquette' '0') -eq '1')
}

# --- Dossier patient : garde-fous -----------------------------------------
# Ce dossier est vide AUTOMATIQUEMENT et DEFINITIVEMENT (chaque soir, et par
# Ctrl+Alt+V) : il doit etre dedie. Refuse les dossiers sensibles et exige un
# fichier marqueur (cree a l'installation dans un dossier vide ou nouveau).

# Renvoie '' si le chemin est acceptable, sinon la raison du refus.
function Get-RefusDossierPatient([string]$Chemin) {
    if ([string]::IsNullOrWhiteSpace($Chemin)) { return 'aucun dossier indiqué' }
    try { $c = [IO.Path]::GetFullPath($Chemin).TrimEnd('\') } catch { return 'chemin invalide' }
    if ($c.Length -le 3 -or $c -match '^\\\\[^\\]+\\[^\\]+$') { return "c'est la racine d'un disque" }
    $profil = $env:USERPROFILE
    $interdits = @(
        $profil, $env:PUBLIC, $env:OneDrive, $env:OneDriveCommercial, $env:OneDriveConsumer,
        [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyDocuments'),
        [Environment]::GetFolderPath('MyPictures'), [Environment]::GetFolderPath('MyMusic'),
        [Environment]::GetFolderPath('MyVideos'), (Join-Path $profil 'Downloads'),
        (Split-Path -Parent $profil)
    ) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
    foreach ($i in $interdits) {
        if ($c -ieq $i) { return "c'est un dossier personnel de Windows ($i)" }
    }
    $racinesInterdites = @(
        $env:windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData,
        $env:APPDATA, $env:LOCALAPPDATA, $script:AppDir, $script:ConfigDir
    ) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
    foreach ($r in $racinesInterdites) {
        if ($c -ieq $r -or $c.StartsWith($r + '\', [StringComparison]::OrdinalIgnoreCase)) {
            return "c'est un dossier système ou de programme ($r)"
        }
    }
    return ''
}

# Dossier synchronise sur internet (OneDrive, Dropbox...) : avertissement
function Test-DossierSynchronise([string]$Chemin) {
    if (-not $Chemin) { return $false }
    if ($env:OneDrive -and $Chemin.StartsWith($env:OneDrive.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return ($Chemin -match '(?i)\\(OneDrive[^\\]*|Dropbox|Google ?Drive|iCloud ?Drive|Mon Drive|My Drive)(\\|$)')
}

# Le dossier est-il bien un dossier patient reconnu (autorise + marqueur) ?
function Test-DossierPatientSur([string]$Chemin) {
    if (Get-RefusDossierPatient $Chemin) { return $false }
    return (Test-Path -LiteralPath (Join-Path $Chemin $script:MarqueurPatient))
}

function New-MarqueurPatient([string]$Chemin) {
    $m = Join-Path $Chemin $script:MarqueurPatient
    if (Test-Path -LiteralPath $m) { return }
    Set-Content -LiteralPath $m -Encoding UTF8 -Value @(
        'Dossier patient de Dr Santé outils.',
        'Son contenu est supprimé automatiquement et définitivement (chaque soir et par Ctrl+Alt+V).',
        "N'y rangez rien d'autre. Ne supprimez pas ce fichier."
    )
    try { (Get-Item -LiteralPath $m -Force).Attributes = 'Hidden' } catch { }
}

# Installation : cree le dossier si besoin et y pose le marqueur. Refuse un
# dossier sensible, ou un dossier existant non vide jamais utilise par l'outil.
function Initialize-DossierPatient([string]$Chemin) {
    $refus = Get-RefusDossierPatient $Chemin
    if ($refus) { throw "Dossier patient refusé : $refus. Choisissez (ou créez) un dossier vide, dédié au dossier patient." }
    if (-not (Test-Path -LiteralPath $Chemin)) { New-Item -ItemType Directory -Path $Chemin -Force | Out-Null }
    if (-not (Test-Path -LiteralPath (Join-Path $Chemin $script:MarqueurPatient))) {
        $n = @(Get-ChildItem -LiteralPath $Chemin -Force -ErrorAction SilentlyContinue).Count
        if ($n -gt 0 -and (Get-IniValue 'general' 'dossier_patient' '') -ne $Chemin) {
            throw "Le dossier patient choisi contient déjà $n élément(s) : il serait vidé automatiquement. Choisissez (ou créez) un dossier vide, dédié au dossier patient."
        }
        New-MarqueurPatient $Chemin
    }
}

# Mise a jour d'un poste existant : pose le marqueur sur le dossier deja
# utilise s'il est acceptable (sinon le nettoyage automatique reste bloque).
function Repair-DossierPatient {
    $dp = Get-IniValue 'general' 'dossier_patient' ''
    if ($dp -and (Test-Path -LiteralPath $dp) -and -not (Get-RefusDossierPatient $dp)) { New-MarqueurPatient $dp }
}

# --- Raccourcis clavier (config.ini, section [raccourcis]) ------------------
# Syntaxe AutoHotkey v2 : ^ = Ctrl, ! = Alt, + = Maj, # = Win, puis la touche.
# Meme liste et memes valeurs par defaut que dans scripts\DrSante.ahk.
$script:RaccourcisDef = @(
    [pscustomobject]@{ Cle = 'adulte';    Defaut = '^MButton';  Nom = 'Consultation adulte' }
    [pscustomobject]@{ Cle = 'enfant';    Defaut = '!MButton';  Nom = 'Consultation enfant' }
    [pscustomobject]@{ Cle = 'courrier';  Defaut = '+MButton';  Nom = "Courrier d'adressage" }
    [pscustomobject]@{ Cle = 'documents'; Defaut = '#MButton'; Nom = 'Menu des documents' }
    [pscustomobject]@{ Cle = 'vider';     Defaut = '^!v';       Nom = 'Vider le dossier patient' }
)

# Touches proposees : Ahk = nom AutoHotkey, Texte = nom affiche, Type = souris / F / lettre
function Get-TouchesRaccourci {
    $l = New-Object System.Collections.Generic.List[object]
    $l.Add([pscustomobject]@{ Ahk = 'MButton';  Texte = 'clic molette';          Type = 'souris' })
    $l.Add([pscustomobject]@{ Ahk = 'XButton1'; Texte = 'bouton souris arrière'; Type = 'souris' })
    $l.Add([pscustomobject]@{ Ahk = 'XButton2'; Texte = 'bouton souris avant';   Type = 'souris' })
    foreach ($i in 1..12) { $l.Add([pscustomobject]@{ Ahk = "F$i"; Texte = "F$i"; Type = 'F' }) }
    foreach ($c in [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
        $l.Add([pscustomobject]@{ Ahk = ([string]$c).ToLower(); Texte = [string]$c; Type = 'lettre' })
    }
    return $l
}

function Get-Raccourci([string]$Cle) {
    $d = ($script:RaccourcisDef | Where-Object { $_.Cle -eq $Cle }).Defaut
    $v = Get-IniValue 'raccourcis' $Cle $d
    if (-not $v) { $v = $d }
    return $v
}

# '^!MButton' -> @{ Ctrl; Alt; Maj; Win; Touche = 'MButton' }
function Split-Raccourci([string]$Ahk) {
    $r = @{ Ctrl = $false; Alt = $false; Maj = $false; Win = $false; Touche = '' }
    if ($Ahk -match '^([\^!+#]*)(.+)$') {
        $p = $Matches[1]
        $r.Ctrl = $p.Contains('^'); $r.Alt = $p.Contains('!')
        $r.Maj = $p.Contains('+');  $r.Win = $p.Contains('#')
        $r.Touche = $Matches[2]
        if ($r.Touche.Length -eq 1) { $r.Touche = $r.Touche.ToLower() }
    }
    return $r
}

# Forme normalisee (toujours dans l'ordre ^ ! + #) : sert aussi aux doublons
function Join-Raccourci([bool]$Ctrl, [bool]$Alt, [bool]$Maj, [bool]$Win, [string]$Touche) {
    $p = ''
    if ($Ctrl) { $p += '^' }; if ($Alt) { $p += '!' }
    if ($Maj)  { $p += '+' }; if ($Win) { $p += '#' }
    return $p + $Touche
}

# '^!MButton' -> 'Ctrl + Alt + clic molette'
function ConvertTo-TexteRaccourci([string]$Ahk) {
    $s = Split-Raccourci $Ahk
    $parts = @()
    if ($s.Ctrl) { $parts += 'Ctrl' }; if ($s.Alt) { $parts += 'Alt' }
    if ($s.Maj)  { $parts += 'Maj' };  if ($s.Win) { $parts += 'Win' }
    $t = Get-TouchesRaccourci | Where-Object { $_.Ahk -eq $s.Touche } | Select-Object -First 1
    if ($t) { $parts += $t.Texte } else { $parts += $s.Touche }
    return ($parts -join ' + ')
}

# --- (Re)lancement des outils (AutoHotkey + surveillance dossier patient) ----
# -ParTache : si le demarrage administrateur est configure, relance via la
# tache planifiee (mode administrateur sans demande d'autorisation).
function Restart-Outils {
    param([switch]$ParTache)
    if ($ParTache -and (Get-IniValue 'general' 'demarrage' '') -eq 'tache') {
        try { Start-ScheduledTask -TaskName $script:NomTache -ErrorAction Stop; return } catch { }
    }
    $ahk = Get-AhkExe
    $ahkScript = Join-Path $script:AppDir 'scripts\DrSante.ahk'
    $watcher   = Join-Path $script:AppDir 'scripts\Aplatir_dossier_patient.ps1'

    # Arrete l'ancienne surveillance pour relancer la version a jour
    Stop-ScriptProcess 'Aplatir_dossier_patient.ps1'
    Start-Sleep -Milliseconds 500

    if ($ahk -and (Test-Path -LiteralPath $ahkScript)) {
        # #SingleInstance Force : remplace l'ancienne instance
        Start-Process -FilePath $ahk -ArgumentList ('"{0}"' -f $ahkScript)
    }
    # Le script gere lui-meme l'instance unique (mutex)
    if (Test-Path -LiteralPath $watcher) {
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $watcher)
        )
    }
}

# Ouvre la fenetre "Dr Sante outils"
function Open-Outil {
    $vbs = Join-Path $script:AppDir 'scripts\Lancer_silencieux.vbs'
    Start-Process -FilePath 'wscript.exe' -ArgumentList ('"{0}" "Outil.ps1"' -f $vbs)
}
