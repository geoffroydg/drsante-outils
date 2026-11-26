# ===========================================================================
# INSTALLATION de "Dr Sante - outils" sur un ordinateur (poste d'un confrere).
# Une fenetre propose : dossier d'installation, dossier patient, imprimante a
# etiquettes, lancement au demarrage (mode administrateur), raccourci bureau.
# Relancer l'installateur = modifier ces choix (config.ini est conserve).
#
# Le plus simple : DrSante-Installation.exe (voir README.md). Sinon, dans PowerShell :
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/geoffroydg/drsante-outils/main/Installer.ps1)))
# ===========================================================================
param(
    [string]$Depot = 'geoffroydg/drsante-outils',
    [string]$Branche = 'main',
    [string]$Token = '',
    [string]$DossierInstallation = '',
    [string]$DossierPatient = '',
    [ValidateSet('', 'oui', 'non')][string]$Etiquette = '',
    [string]$Lbx = '',
    [switch]$SansFenetre
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$titre = 'Dr Sante - installation'
# Toute erreur : message clair au lieu d'une fenetre qui se ferme
trap {
    [System.Windows.Forms.MessageBox]::Show(
        "L'installation a echoue :`n`n$($_.Exception.Message)`n`nReessayez ; si le probleme persiste, envoyez une photo de ce message a l'administrateur.",
        $titre, 'OK', 'Error') | Out-Null
    break
}
function Info($m) { Write-Host "[Dr Sante] $m" -ForegroundColor Cyan }

if ([string]::IsNullOrWhiteSpace($Depot) -or $Depot -like '__*__') {
    throw "Depot non renseigne. Relancez avec : -Depot proprietaire/nom-du-depot"
}

# --- Fenetre d'installation ------------------------------------------------
function Select-Dossier([string]$Description, [string]$Initial) {
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = $Description
    $d.ShowNewFolderButton = $true
    if ($Initial -and (Test-Path -LiteralPath $Initial)) { $d.SelectedPath = $Initial }
    if ($d.ShowDialog() -eq 'OK' -and $d.SelectedPath) { return $d.SelectedPath }
    return $null
}

function Add-Champ($Parent, [int]$X, [int]$Y, [string]$Texte, [string]$Valeur, [scriptblock]$Parcourir) {
    $l = Add-Ctrl 'Label' $Parent $X $Y ($Parent.Width - $X - 16) 20 $Texte
    $t = Add-Ctrl 'TextBox' $Parent $X ($Y + 22) ($Parent.Width - $X - 136) 0 $Valeur
    $b = Add-Bouton $Parent ($Parent.Width - 126) ($Y + 20) 110 'Parcourir...' -H 28
    $b.Tag = @{ Champ = $t; Action = $Parcourir }
    $b.Add_Click({ param($s, $e) & $s.Tag.Action $s.Tag.Champ })
    return @($l, $t, $b)
}

function Add-Case($Parent, [int]$X, [int]$Y, [string]$Texte, [bool]$Coche) {
    $c = Add-Ctrl 'CheckBox' $Parent $X $Y 0 0 $Texte
    $c.Checked = $Coche; $c.AutoSize = $true
    return $c
}

function Show-FenetreInstallation($c) {
    $f = New-Fenetre 'Dr Santé outils : installation' 600 552
    $f.MinimizeBox = $false
    $f.Add_Shown({ $f.Activate() })
    $null = Add-Entete $f 'Installation' 'Dr Santé outils  ·  réglages de cet ordinateur (modifiables ensuite)'

    $cd = Add-Carte $f 20 88 560 156 'Dossiers'
    $app = Add-Champ $cd 16 42 "Dossier d'installation des outils (scripts, prompt Heidi)" $c.App {
        param($t)
        $s = Select-Dossier "Choisissez (ou creez) le dossier ou installer les outils." $t.Text
        if ($s) {
            if ((Split-Path -Leaf $s) -ne 'DrSanteOutils') { $s = Join-Path $s 'DrSanteOutils' }
            $t.Text = $s
        }
    }
    $pat = Add-Champ $cd 16 96 "Dossier patient (où Dr Santé extrait les documents ; créé s'il n'existe pas)" $c.Patient {
        param($t)
        $s = Select-Dossier "Choisissez (ou creez) le dossier ou Dr Sante extrait le dossier patient. Il sera range et vide automatiquement : n'y mettez rien d'autre." $t.Text
        if ($s) { $t.Text = $s }
    }

    $co = Add-Carte $f 20 256 560 232 'Options'
    $cbEti = Add-Case $co 16 42 "Imprimante à étiquettes Brother (étiquette du carnet de santé, enfants)" $c.Etiquette
    $lbx = Add-Champ $co 36 66 "Modèle d'étiquette (fichier .lbx)" $c.Lbx {
        param($t)
        $o = New-Object System.Windows.Forms.OpenFileDialog
        $o.Title = "Choisissez le modele d'etiquette (fichier .lbx)"
        $o.Filter = 'Modele Brother (*.lbx)|*.lbx'
        if ($o.ShowDialog() -eq 'OK') { $t.Text = $o.FileName }
    }
    $majEti = { foreach ($x in $lbx) { $x.Enabled = $cbEti.Checked } }
    $cbEti.Add_CheckedChanged($majEti); & $majEti

    $cbDem = Add-Case $co 16 126 "Lancer les outils à l'ouverture de Windows (recommandé)" $c.Demarrage
    $cbAdm = Add-Case $co 36 150 "En mode administrateur (recommandé : collage fiable dans Dr Santé)" $c.Admin
    $note = Add-Ctrl 'Label' $co 54 172 490 20 "Windows demandera une seule fois l'autorisation, maintenant."
    $note.ForeColor = $script:Theme.TexteDoux; $note.Font = $script:PolicePetite
    $majDem = { $cbAdm.Enabled = $cbDem.Checked; $note.Enabled = $cbDem.Checked }
    $cbDem.Add_CheckedChanged($majDem); & $majDem

    $cbBur = Add-Case $co 16 198 "Icône « Dr Santé outils » sur le bureau (sinon : menu Démarrer)" $c.Bureau

    $ok = Add-Bouton $f 352 504 110 'Installer' -Primaire
    $ok.DialogResult = 'OK'
    $f.AcceptButton = $ok
    $an = Add-Bouton $f 470 504 110 'Annuler'
    $an.DialogResult = 'Cancel'
    $f.CancelButton = $an

    $f.Add_FormClosing({
        param($s, $e)
        if ($f.DialogResult -ne 'OK') { return }
        if ([string]::IsNullOrWhiteSpace($app[1].Text) -or [string]::IsNullOrWhiteSpace($pat[1].Text)) {
            [System.Windows.Forms.MessageBox]::Show('Indiquez les deux dossiers.', $titre, 'OK', 'Warning') | Out-Null
            $e.Cancel = $true
        }
    })

    if ($f.ShowDialog() -ne 'OK') { return $null }
    return [pscustomobject]@{
        App       = $app[1].Text.Trim()
        Patient   = $pat[1].Text.Trim()
        Etiquette = $cbEti.Checked
        Lbx       = $lbx[1].Text.Trim()
        Demarrage = $cbDem.Checked
        Admin     = ($cbDem.Checked -and $cbAdm.Checked)
        Bureau    = $cbBur.Checked
    }
}

# --- Demarrage en mode administrateur (tache planifiee, 1 autorisation) -----
function Invoke-ConfigDemarrage([string]$Vbs, [switch]$Supprimer) {
    $cfg = Join-Path $script:AppDir 'scripts\Configurer_demarrage.ps1'
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $a = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Utilisateur "{1}"' -f $cfg, $user
    if ($Supprimer) { $a += ' -Supprimer' } else { $a += (' -Vbs "{0}"' -f $Vbs) }
    try {
        $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ArgumentList $a
        return ($p.ExitCode -eq 0)
    }
    catch { return $false }   # autorisation refusee
}

function New-Raccourci([string]$Chemin, [string]$Vbs, [string]$Script, [string]$Extra = '') {
    $dir = Split-Path -Parent $Chemin
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $l = (New-Object -ComObject WScript.Shell).CreateShortcut($Chemin)
    $l.TargetPath = 'wscript.exe'
    $l.Arguments = ('"{0}" "{1}" {2}' -f $Vbs, $Script, $Extra).Trim()
    $l.WorkingDirectory = Split-Path -Parent $Vbs
    $l.Save()
}

# --- 1) Telechargement du depot (dossier temporaire) ------------------------
Info 'Telechargement des outils...'
$h = @{ 'User-Agent' = 'DrSanteOutils'; 'Accept' = 'application/vnd.github+json' }
if ($Token) { $h['Authorization'] = "Bearer $Token" }
$tmp = Join-Path $env:TEMP ('drsante_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $zip = Join-Path $tmp 'depot.zip'
    Invoke-WebRequest -UseBasicParsing -OutFile $zip -Headers $h `
        -Uri "https://api.github.com/repos/$Depot/zipball/$Branche"
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'x') -Force
    $source = (Get-ChildItem -LiteralPath (Join-Path $tmp 'x') -Directory | Select-Object -First 1).FullName

    # Fonctions communes (lecture de config.ini pour les valeurs par defaut)
    . (Join-Path $source 'scripts\Commun.ps1')
    # Apparence des fenetres (nettete sur ecran agrandi) ; absent des anciennes versions
    $ui = Join-Path $source 'scripts\Interface.ps1'
    if (Test-Path -LiteralPath $ui) { . $ui }

    # --- 2) Choix de l'utilisateur ------------------------------------------
    $dem = Get-IniValue 'general' 'demarrage' 'tache'
    $choix = [pscustomobject]@{
        App       = Get-IniValue 'general' 'dossier_app' (Join-Path $env:LOCALAPPDATA 'DrSanteOutils\app')
        Patient   = Get-IniValue 'general' 'dossier_patient' (Join-Path $env:USERPROFILE 'Documents\Dossier patient')
        Etiquette = ((Get-IniValue 'general' 'etiquette' '0') -eq '1')
        Lbx       = Get-IniValue 'etiquette' 'lbx' ''
        Demarrage = ($dem -ne 'non')
        Admin     = ($dem -eq 'tache')
        Bureau    = $true
    }
    if ($DossierInstallation) { $choix.App = $DossierInstallation }
    if ($DossierPatient) { $choix.Patient = $DossierPatient }
    if ($Etiquette) { $choix.Etiquette = ($Etiquette -eq 'oui') }
    if ($Lbx) { $choix.Lbx = $Lbx }

    if (-not $SansFenetre) {
        $choix = Show-FenetreInstallation $choix
        if (-not $choix) { Info 'Installation annulee.'; return }
    }

    # --- 3) Copie des outils dans le dossier choisi -------------------------
    New-Item -ItemType Directory -Path $choix.App -Force | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $choix.App -Recurse -Force
}
finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

. (Join-Path $choix.App 'scripts\Commun.ps1')

# --- 4) Configuration de ce poste (config.ini) ------------------------------
Set-IniValue 'depot' 'nom' $Depot
Set-IniValue 'depot' 'branche' $Branche
if ($Token) { Save-Token $Token }
Set-IniValue 'general' 'dossier_app' $choix.App
Set-IniValue 'general' 'dossier_patient' $choix.Patient
if (-not (Test-Path -LiteralPath $choix.Patient)) { New-Item -ItemType Directory -Path $choix.Patient -Force | Out-Null }
Set-IniValue 'general' 'etiquette' $(if ($choix.Etiquette) { '1' } else { '0' })
if ($choix.Lbx) { Set-IniValue 'etiquette' 'lbx' $choix.Lbx }

# --- 5) AutoHotkey v2 -------------------------------------------------------
if (-not (Get-AhkExe)) {
    Info 'Installation de AutoHotkey v2 (une fenetre Windows peut demander une autorisation)...'
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget est introuvable. Installez AutoHotkey v2 depuis https://www.autohotkey.com puis relancez l'installateur."
    }
    & winget install --id AutoHotkey.AutoHotkey -e --silent --accept-package-agreements --accept-source-agreements
    if (-not (Get-AhkExe)) {
        throw "AutoHotkey v2 n'a pas pu etre installe automatiquement. Installez-le depuis https://www.autohotkey.com puis relancez l'installateur."
    }
}

# Version installee (la prochaine mise a jour sera proposee a partir de celle-ci)
try { Set-Content -LiteralPath $script:ShaFile -Value (Get-RemoteSha) -Encoding ASCII } catch { }

# --- 6) Lancement au demarrage de Windows -----------------------------------
$vbs = Join-Path $script:AppDir 'scripts\Lancer_silencieux.vbs'
$lnkDemarrage = Join-Path ([Environment]::GetFolderPath('Startup')) 'Dr Sante outils.lnk'
$ancien = Get-IniValue 'general' 'demarrage' ''
$mode = 'non'
if ($choix.Admin) {
    Info "Mode administrateur : acceptez la demande d'autorisation de Windows..."
    if (Invoke-ConfigDemarrage -Vbs $vbs) { $mode = 'tache' }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "Le mode administrateur n'a pas ete active (autorisation refusee).`n`nLes outils se lanceront quand meme au demarrage, en mode normal. Relancez l'installateur pour reessayer.",
            $titre, 'OK', 'Warning') | Out-Null
        $mode = 'raccourci'
    }
}
elseif ($choix.Demarrage) { $mode = 'raccourci' }

if ($mode -ne 'tache' -and $ancien -eq 'tache') { $null = Invoke-ConfigDemarrage -Supprimer }
if ($mode -eq 'raccourci') { New-Raccourci $lnkDemarrage $vbs 'Demarrer.ps1' }
else { Remove-Item -LiteralPath $lnkDemarrage -Force -ErrorAction SilentlyContinue }
Set-IniValue 'general' 'demarrage' $mode

# --- 7) Acces a l'outil : menu Demarrer (+ bureau si choisi) ---------------
$bureau = [Environment]::GetFolderPath('Desktop')
$menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Dr Sante outils'
# Anciens raccourcis (versions precedentes)
foreach ($vieux in @((Join-Path $bureau 'Copier prompt Heidi.lnk'),
                     (Join-Path $menu 'Copier prompt Heidi.lnk'),
                     (Join-Path $menu 'Rechercher une mise a jour.lnk'))) {
    Remove-Item -LiteralPath $vieux -Force -ErrorAction SilentlyContinue
}
New-Raccourci (Join-Path $menu 'Dr Sante outils.lnk') $vbs 'Outil.ps1'
$lnkBureau = Join-Path $bureau 'Dr Sante outils.lnk'
if ($choix.Bureau) { New-Raccourci $lnkBureau $vbs 'Outil.ps1' }
else { Remove-Item -LiteralPath $lnkBureau -Force -ErrorAction SilentlyContinue }

# --- 8) Premier lancement ---------------------------------------------------
Info 'Lancement...'
$lance = $false
if ($mode -eq 'tache') {
    try { Start-ScheduledTask -TaskName $script:NomTache -ErrorAction Stop; $lance = $true } catch { }
}
if (-not $lance) { Start-Process -FilePath 'wscript.exe' -ArgumentList ('"{0}" "Demarrer.ps1"' -f $vbs) }

[System.Windows.Forms.MessageBox]::Show(
    "Installation terminee.`n`nLa fenetre 'Dr Sante outils' va s'ouvrir : cliquez sur 'Copier le prompt Heidi' puis collez-le dans votre modele Heidi.`n`nPour la retrouver : menu Demarrer > Dr Sante outils.",
    $titre, 'OK', 'Information') | Out-Null
Open-Outil
