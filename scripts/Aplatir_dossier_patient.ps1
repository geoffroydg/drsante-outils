# ===========================================================================
# Aplatissement AUTOMATIQUE du dossier patient - 100 % local, aucun reseau
#
# Tout fichier qui arrive dans le dossier patient (y compris dans des
# sous-dossiers comme VSM) est remonte a la racine, puis les sous-dossiers
# devenus vides sont supprimes. Notification discrete pres de l'horloge.
#
# Nettoyage de securite (filet contre les oublis) :
#   - chaque jour a $purgeHour h : si le dossier est inactif depuis 30 min,
#     son contenu est supprime definitivement ;
#   - au demarrage : si plus rien n'a bouge depuis 8 h, idem.
#
# Garanties : aucun fichier ecrase (doublon -> "nom (1).ext"), aucune fusion
# PDF, 0 % CPU au repos, journal sans noms de fichiers (compteurs seulement).
# Le dossier surveille est lu dans config.ini (cle dossier_patient).
# ===========================================================================

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Commun.ps1')

$configDir = $script:ConfigDir
if (-not (Test-Path -LiteralPath $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
$watchPath = Get-IniValue 'general' 'dossier_patient' (Join-Path $env:USERPROFILE 'Documents\Dossier patient')
$logPath   = Join-Path $configDir 'journal_aplatissement.txt'

$junkNames    = @('desktop.ini', 'Thumbs.db', '.dropbox', '.dropbox.attr')
$quietSeconds = 4      # le dossier doit etre calme pendant 4 s avant traitement
$maxRetries   = 5      # essais sur un fichier encore verrouille
$retryDelayMs = 400
$maxPasses    = 6      # passages si des fichiers restent verrouilles
$passDelaySec = 5
$purgeHour        = 20   # heure du nettoyage quotidien (20 = 20 h 00)
$purgeIdleMinutes = 30   # inactivite minimale avant le nettoyage quotidien
$startupStaleHours = 8   # au demarrage : nettoyage si inactif depuis 8 h

# --- Une seule instance a la fois ------------------------------------------
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\AplatirDossierPatient', [ref]$createdNew)
if (-not $createdNew) { exit }

if (-not (Test-Path -LiteralPath $watchPath)) {
    New-Item -ItemType Directory -Path $watchPath -Force | Out-Null
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:lastActivity = [DateTime]::MinValue

# --- Notification discrete (ne prend pas le focus) -------------------------
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon    = [System.Drawing.SystemIcons]::Information
$tray.Text    = 'Dossier patient : surveillance active'
$tray.Visible = $true

function Show-Notif {
    param([string]$Title, [string]$Text)
    try {
        $tray.BalloonTipTitle = $Title
        $tray.BalloonTipText  = $Text
        $tray.ShowBalloonTip(4000)
    } catch { }
}

function Write-Log {
    param([string]$Message)
    try {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" |
            Out-File -FilePath $logPath -Append -Encoding UTF8
    } catch { }
}

# Chemin libre : "nom.ext" puis "nom (1).ext", "nom (2).ext"...
function Get-UniquePath {
    param([string]$Folder, [string]$Name)
    $dest = Join-Path $Folder $Name
    if (-not (Test-Path -LiteralPath $dest)) { return $dest }
    $base = [IO.Path]::GetFileNameWithoutExtension($Name)
    $ext  = [IO.Path]::GetExtension($Name)
    $i = 1
    do {
        $dest = Join-Path $Folder ("{0} ({1}){2}" -f $base, $i, $ext)
        $i++
    } while (Test-Path -LiteralPath $dest)
    return $dest
}

# Le fichier est-il libre (plus en cours d'ecriture par Dr Sante ou de synchro) ?
function Test-FileReady {
    param([string]$Path)
    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            $fs = [IO.File]::Open($Path, 'Open', 'Read', 'None')
            $fs.Close()
            return $true
        } catch { Start-Sleep -Milliseconds $retryDelayMs }
    }
    return $false
}

function Move-FileSafe {
    param([string]$Source, [string]$Destination)
    try {
        # Pas de -Force : un fichier existant n'est jamais ecrase
        Move-Item -LiteralPath $Source -Destination $Destination -ErrorAction Stop
        return $true
    } catch { return $false }
}

# Un passage : remonte tout a la racine, supprime les sous-dossiers vides.
function Invoke-Flatten {
    $moved = 0
    $left  = 0

    $files = @(Get-ChildItem -LiteralPath $watchPath -File -Recurse -Force |
        Where-Object { $_.DirectoryName -ne $watchPath })

    foreach ($f in $files) {
        if ($junkNames -contains $f.Name) {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
            continue
        }
        if (-not (Test-FileReady -Path $f.FullName)) { $left++; continue }

        $dest = Get-UniquePath -Folder $watchPath -Name $f.Name
        if (Move-FileSafe -Source $f.FullName -Destination $dest) { $moved++ } else { $left++ }
    }

    # Dossiers : du plus profond au plus haut. Delete($chemin, $false) refuse
    # de supprimer un dossier NON vide -> impossible de perdre un fichier.
    $dirs = @(Get-ChildItem -LiteralPath $watchPath -Directory -Recurse -Force |
        Sort-Object { $_.FullName.Length } -Descending)
    $removed = 0
    foreach ($d in $dirs) {
        try { [IO.Directory]::Delete($d.FullName, $false); $removed++ } catch { }
    }

    return [pscustomobject]@{ Moved = $moved; Left = $left; DirsRemoved = $removed }
}

# Un cycle complet, avec nouveaux essais si des fichiers sont encore verrouilles.
function Invoke-Cycle {
    $totalMoved = 0; $totalDirs = 0; $left = 0
    for ($pass = 1; $pass -le $maxPasses; $pass++) {
        $r = Invoke-Flatten
        $totalMoved += $r.Moved
        $totalDirs  += $r.DirsRemoved
        $left = $r.Left
        if ($left -eq 0) { break }
        Start-Sleep -Seconds $passDelaySec
    }
    if ($totalMoved -gt 0 -or $totalDirs -gt 0 -or $left -gt 0) {
        Write-Log "Aplatissement : $totalMoved fichier(s) remontes, $totalDirs sous-dossier(s) supprimes, $left fichier(s) restes verrouilles"
        $total = @(Get-ChildItem -LiteralPath $watchPath -File -Force -ErrorAction SilentlyContinue).Count
        if ($left -gt 0) {
            Show-Notif 'Dossier patient' "ATTENTION : $left fichier(s) encore verrouille(s), non ranges."
        } else {
            Show-Notif 'Dossier patient' "$total fichier(s) a plat, pret pour Heidi."
        }
    }
}

# --- Nettoyage de securite --------------------------------------------------
function Get-LastActivity {
    $newest = [DateTime]::MinValue
    foreach ($i in (Get-ChildItem -LiteralPath $watchPath -Recurse -Force -ErrorAction SilentlyContinue)) {
        if ($i.LastWriteTime -gt $newest) { $newest = $i.LastWriteTime }
        if ($i.CreationTime  -gt $newest) { $newest = $i.CreationTime }
    }
    if ($script:lastActivity -gt $newest) { $newest = $script:lastActivity }
    return $newest
}

# Renvoie $true si le dossier est vide ou a ete vide ; $false si on a renonce
# (dossier encore actif, ou suppression incomplete) -> on reessaiera plus tard.
function Invoke-AutoPurge {
    param([double]$MinIdleMinutes)

    $items = @(Get-ChildItem -LiteralPath $watchPath -Force -ErrorAction SilentlyContinue)
    if ($items.Count -eq 0) { return $true }

    $idle = ((Get-Date) - (Get-LastActivity)).TotalMinutes
    if ($idle -lt $MinIdleMinutes) { return $false }

    $count  = @(Get-ChildItem -LiteralPath $watchPath -File -Recurse -Force -ErrorAction SilentlyContinue).Count
    $failed = 0
    foreach ($it in $items) {
        try   { Remove-Item -LiteralPath $it.FullName -Recurse -Force -ErrorAction Stop }
        catch { $failed++ }
    }
    Write-Log "Nettoyage automatique : $count fichier(s) supprimes, $failed element(s) non supprimes"
    if ($failed -gt 0) {
        Show-Notif 'Dossier patient' "Nettoyage automatique incomplet : $failed element(s) restent (fichier ouvert ?)."
        return $false
    }
    Show-Notif 'Dossier patient' "Nettoyage automatique : $count fichier(s) supprime(s)."
    return $true
}

function Get-NextPurgeTime {
    $t = (Get-Date).Date.AddHours($purgeHour)
    if ($t -le (Get-Date)) { $t = $t.AddDays(1) }
    return $t
}

# --- Surveillance par evenements (pas de boucle de scan) -------------------
$fsw = New-Object IO.FileSystemWatcher $watchPath
$fsw.IncludeSubdirectories = $true
$fsw.InternalBufferSize    = 65536
$fsw.NotifyFilter = [IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
$null = Register-ObjectEvent $fsw Created -SourceIdentifier 'apCreated'
$null = Register-ObjectEvent $fsw Renamed -SourceIdentifier 'apRenamed'
$null = Register-ObjectEvent $fsw Changed -SourceIdentifier 'apChanged'
$null = Register-ObjectEvent $fsw Error   -SourceIdentifier 'apError'
$fsw.EnableRaisingEvents = $true

try {
    # Au demarrage : nettoyage d'un dossier oublie, sinon rangement de l'existant.
    $null = Invoke-AutoPurge -MinIdleMinutes ($startupStaleHours * 60)
    Invoke-Cycle
    Start-Sleep -Milliseconds 800
    Get-Event | Remove-Event

    $nextPurge = Get-NextPurgeTime

    while ($true) {
        # Dort sans consommer de CPU jusqu'a un evenement OU l'heure du nettoyage
        $wait = [int][Math]::Ceiling(($nextPurge - (Get-Date)).TotalSeconds)
        if ($wait -lt 1) { $wait = 1 }
        $ev = Wait-Event -Timeout $wait

        if ($null -eq $ev) {
            if ((Get-Date) -ge $nextPurge) {
                if (Invoke-AutoPurge -MinIdleMinutes $purgeIdleMinutes) {
                    $nextPurge = Get-NextPurgeTime
                } else {
                    $nextPurge = (Get-Date).AddMinutes(30)   # encore actif : on reessaie
                }
                Start-Sleep -Milliseconds 800
                Get-Event | Remove-Event
            }
            continue
        }

        # Attend que le dossier soit calme (Dr Sante depose souvent par vagues)
        while ($null -ne (Wait-Event -Timeout $quietSeconds)) {
            Get-Event | Remove-Event
        }
        Get-Event | Remove-Event

        try { Invoke-Cycle } catch { Write-Log "ERREUR inattendue : $($_.Exception.GetType().Name)" }
        $script:lastActivity = Get-Date

        # Ignore les evenements provoques par nos propres deplacements
        Start-Sleep -Milliseconds 800
        Get-Event | Remove-Event
    }
}
finally {
    $fsw.EnableRaisingEvents = $false
    $fsw.Dispose()
    Get-EventSubscriber | Unregister-Event -Force -ErrorAction SilentlyContinue
    $tray.Visible = $false
    $tray.Dispose()
    $mutex.ReleaseMutex()
}
