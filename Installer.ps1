﻿# ===========================================================================
# INSTALLATION de "Dr Sante - outils" sur un ordinateur (poste d'un confrere).
# Une fenetre propose : dossier d'installation, dossier patient, imprimante a
# etiquettes, lancement au demarrage (mode administrateur), raccourci bureau.
# Relancer l'installateur = modifier ces choix (config.ini est conserve).
#
# Depot public :
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/geoffroydg/drsante-outils/main/Installer.ps1)))
# Depot prive (jeton de lecture fourni par l'administrateur) : voir README.md
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

function Add-Champ($Form, [int]$X, [int]$Y, [string]$Texte, [string]$Valeur, [scriptblock]$Parcourir) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Texte; $l.AutoSize = $true
    $l.Location = New-Object System.Drawing.Point($X, $Y)
    $Form.Controls.Add($l)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Text = $Valeur; $t.Width = 445 - $X
    $t.Location = New-Object System.Drawing.Point($X, ($Y + 20))
    $Form.Controls.Add($t)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = 'Parcourir...'; $b.Width = 95
    $b.Location = New-Object System.Drawing.Point(455, ($Y + 19))
    $Form.Controls.Add($b)
    $b.Tag = @{ Champ = $t; Action = $Parcourir }
    $b.Add_Click({ param($s, $e) & $s.Tag.Action $s.Tag.Champ })
    return @($l, $t, $b)
}

function Add-Case($Form, [int]$X, [int]$Y, [string]$Texte, [bool]$Coche) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $Texte; $c.Checked = $Coche; $c.AutoSize = $true
    $c.Location = New-Object System.Drawing.Point($X, $Y)
    $Form.Controls.Add($c)
    return $c
}

function Show-FenetreInstallation($c) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = 'Dr Sante - outils : installation'
    $f.StartPosition = 'CenterScreen'
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.ClientSize = New-Object System.Drawing.Size(565, 420)
    $f.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $f.Add_Shown({ $f.Activate() })

    $app = Add-Champ $f 15 15 "Dossier ou installer les outils (scripts, prompt Heidi) :" $c.App {
        param($t)
        $s = Select-Dossier "Choisissez (ou creez) le dossier ou installer les outils." $t.Text
        if ($s) {
            if ((Split-Path -Leaf $s) -ne 'DrSanteOutils') { $s = Join-Path $s 'DrSanteOutils' }
            $t.Text = $s
        }
    }
    $pat = Add-Champ $f 15 75 "Dossier patient (ou Dr Sante extrait les documents ; cree s'il n'existe pas) :" $c.Patient {
        param($t)
        $s = Select-Dossier "Choisissez (ou creez) le dossier ou Dr Sante extrait le dossier patient. Il sera range et vide automatiquement : n'y mettez rien d'autre." $t.Text
        if ($s) { $t.Text = $s }
    }

    $cbEti = Add-Case $f 15 140 "Imprimante a etiquettes Brother (etiquette du carnet de sante, enfants)" $c.Etiquette
    $lbx = Add-Champ $f 35 165 "Modele d'etiquette (fichier .lbx) :" $c.Lbx {
        param($t)
        $o = New-Object System.Windows.Forms.OpenFileDialog
        $o.Title = "Choisissez le modele d'etiquette (fichier .lbx)"
        $o.Filter = 'Modele Brother (*.lbx)|*.lbx'
        if ($o.ShowDialog() -eq 'OK') { $t.Text = $o.FileName }
    }
    $majEti = { foreach ($x in $lbx) { $x.Enabled = $cbEti.Checked } }
    $cbEti.Add_CheckedChanged($majEti); & $majEti

    $cbDem = Add-Case $f 15 235 "Lancer les outils automatiquement a l'ouverture de Windows (recommande)" $c.Demarrage
    $cbAdm = Add-Case $f 35 260 "En mode administrateur (recommande : collage fiable dans Dr Sante)" $c.Admin
    $note = New-Object System.Windows.Forms.Label
    $note.Text = "Windows demandera une seule fois l'autorisation, maintenant."
    $note.AutoSize = $true; $note.ForeColor = [System.Drawing.Color]::DimGray
    $note.Location = New-Object System.Drawing.Point(52, 283)
    $f.Controls.Add($note)
    $majDem = { $cbAdm.Enabled = $cbDem.Checked; $note.Enabled = $cbDem.Checked }
    $cbDem.Add_CheckedChanged($majDem); & $majDem

    $cbBur = Add-Case $f 15 315 "Raccourci 'Copier prompt Heidi' sur le bureau" $c.Bureau

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Installer'; $ok.Width = 110
    $ok.Location = New-Object System.Drawing.Point(320, 375)
    $ok.DialogResult = 'OK'
    $f.Controls.Add($ok); $f.AcceptButton = $ok
    $an = New-Object System.Windows.Forms.Button
    $an.Text = 'Annuler'; $an.Width = 110
    $an.Location = New-Object System.Drawing.Point(440, 375)
    $an.DialogResult = 'Cancel'
    $f.Controls.Add($an); $f.CancelButton = $an

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

# --- 7) Raccourcis : bureau + menu Demarrer ---------------------------------
$lnkBureau = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Copier prompt Heidi.lnk'
if ($choix.Bureau) { New-Raccourci $lnkBureau $vbs 'Copier_prompt_Heidi.ps1' }
else { Remove-Item -LiteralPath $lnkBureau -Force -ErrorAction SilentlyContinue }

$menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Dr Sante outils'
New-Raccourci (Join-Path $menu 'Copier prompt Heidi.lnk') $vbs 'Copier_prompt_Heidi.ps1'
New-Raccourci (Join-Path $menu 'Rechercher une mise a jour.lnk') $vbs 'Demarrer.ps1' '-Manuel'

# --- 8) Premier lancement ---------------------------------------------------
Info 'Lancement...'
$lance = $false
if ($mode -eq 'tache') {
    try { Start-ScheduledTask -TaskName $script:NomTache -ErrorAction Stop; $lance = $true } catch { }
}
if (-not $lance) { Start-Process -FilePath 'wscript.exe' -ArgumentList ('"{0}" "Demarrer.ps1"' -f $vbs) }

$rep = [System.Windows.Forms.MessageBox]::Show(
    "Installation terminee.`n`nCopier maintenant le prompt Heidi ? Il suffira ensuite de le coller (Ctrl+V) dans votre modele Heidi.`n`n(Plus tard : raccourci 'Copier prompt Heidi' du bureau ou du menu Demarrer.)",
    $titre, 'YesNo', 'Information')
if ($rep -eq 'Yes') {
    $null = Copy-HeidiPrompt
    [System.Windows.Forms.MessageBox]::Show(
        "Prompt copie. Collez-le (Ctrl+V) dans votre modele Heidi, a la place de l'ancien.`n`nLes mises a jour vous seront proposees a l'ouverture de Windows.",
        $titre, 'OK', 'Information') | Out-Null
}
