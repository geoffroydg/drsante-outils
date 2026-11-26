# ===========================================================================
# INSTALLATION de "Dr Sante - outils" sur un ordinateur (poste d'un confrere).
# Tout est automatique : AutoHotkey, configuration, mises a jour, raccourcis.
#
# Depot public :
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/geoffroydg/drsante-outils/main/Installer.ps1)))
# Depot prive (jeton de lecture fourni par l'administrateur) : voir README.md
# ===========================================================================
param(
    [string]$Depot = 'geoffroydg/drsante-outils',
    [string]$Branche = 'main',
    [string]$Token = '',
    [string]$DossierPatient = '',
    [ValidateSet('', 'oui', 'non')][string]$Etiquette = '',
    [string]$Lbx = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

function Info($m) { Write-Host "[Dr Sante] $m" -ForegroundColor Cyan }

if ([string]::IsNullOrWhiteSpace($Depot) -or $Depot -like '__*__') {
    throw "Depot non renseigne. Relancez avec : -Depot proprietaire/nom-du-depot"
}

$racine = Join-Path $env:LOCALAPPDATA 'DrSanteOutils'
$appDir = Join-Path $racine 'app'
New-Item -ItemType Directory -Path $appDir -Force | Out-Null

# --- 1) Telechargement initial du depot (avant d'avoir Commun.ps1) ---------
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
    $rootFolder = Get-ChildItem -LiteralPath (Join-Path $tmp 'x') -Directory | Select-Object -First 1
    Copy-Item -Path (Join-Path $rootFolder.FullName '*') -Destination $appDir -Recurse -Force
}
finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

. (Join-Path $appDir 'scripts\Commun.ps1')

# --- 2) Configuration de ce poste (conservee si deja presente) -------------
Set-IniValue 'depot' 'nom' $Depot
Set-IniValue 'depot' 'branche' $Branche
if ($Token) { Save-Token $Token }

if ($DossierPatient) {
    Set-IniValue 'general' 'dossier_patient' $DossierPatient
}
elseif (-not (Get-IniValue 'general' 'dossier_patient' '')) {
    $defaut = Join-Path $env:USERPROFILE 'Documents\Dossier patient'
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Choisissez le dossier ou Dr Sante extrait le dossier patient (il sera range et nettoye automatiquement). Annuler = " + $defaut
    $dlg.ShowNewFolderButton = $true
    $choix = $defaut
    if ($dlg.ShowDialog() -eq 'OK' -and $dlg.SelectedPath) { $choix = $dlg.SelectedPath }
    Set-IniValue 'general' 'dossier_patient' $choix
}

if ($Etiquette) {
    Set-IniValue 'general' 'etiquette' $(if ($Etiquette -eq 'oui') { '1' } else { '0' })
    if ($Lbx) { Set-IniValue 'etiquette' 'lbx' $Lbx }
}
elseif (-not (Get-IniValue 'general' 'etiquette' '')) {
    $rep = [System.Windows.Forms.MessageBox]::Show(
        "Ce poste a-t-il une imprimante a etiquettes Brother (etiquette du carnet de sante pour les enfants) ?",
        'Dr Sante - installation', 'YesNo', 'Question')
    if ($rep -eq 'Yes') {
        Set-IniValue 'general' 'etiquette' '1'
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Title = "Choisissez le modele d'etiquette (fichier .lbx)"
        $ofd.Filter = 'Modele Brother (*.lbx)|*.lbx'
        if ($ofd.ShowDialog() -eq 'OK') { Set-IniValue 'etiquette' 'lbx' $ofd.FileName }
    }
    else { Set-IniValue 'general' 'etiquette' '0' }
}

# --- 3) AutoHotkey v2 -------------------------------------------------------
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

# --- 4) Version installee, raccourcis, premier lancement -------------------
try { Set-Content -LiteralPath $script:ShaFile -Value (Get-RemoteSha) -Encoding ASCII } catch { }

$wsh = New-Object -ComObject WScript.Shell
$vbs = Join-Path $appDir 'scripts\Lancer_silencieux.vbs'

# Demarrage automatique a l'ouverture de session
$lnk = $wsh.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'Dr Sante outils.lnk'))
$lnk.TargetPath = 'wscript.exe'
$lnk.Arguments = '"' + $vbs + '" "Demarrer.ps1"'
$lnk.WorkingDirectory = Join-Path $appDir 'scripts'
$lnk.Save()

# Raccourci bureau : copier le prompt Heidi a jour
$lnk2 = $wsh.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Copier prompt Heidi.lnk'))
$lnk2.TargetPath = 'wscript.exe'
$lnk2.Arguments = '"' + $vbs + '" "Copier_prompt_Heidi.ps1"'
$lnk2.WorkingDirectory = Join-Path $appDir 'scripts'
$lnk2.Save()

Info 'Lancement...'
Start-Process -FilePath 'wscript.exe' -ArgumentList ('"{0}" "Demarrer.ps1"' -f $vbs)

[System.Windows.Forms.MessageBox]::Show(
    "Installation terminee.`n`nDerniere etape : double-cliquez sur le raccourci 'Copier prompt Heidi' du bureau, puis collez le prompt dans votre modele Heidi.`n`nLes mises a jour suivantes sont automatiques.",
    'Dr Sante - installation', 'OK', 'Information') | Out-Null
