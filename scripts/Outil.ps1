# ===========================================================================
# Fenetre principale "Dr Santé outils" (menu Demarrer / bureau) :
#  - prompt Heidi : etat (a jour ou non par rapport aux scripts installes),
#    copie en un clic, affichage du texte ;
#  - mises a jour : verification et installation ;
#  - ce poste : dossier patient, demarrage, modification des reglages ;
#  - rappel des raccourcis clavier dans Dr Santé.
# ===========================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'Commun.ps1')

# Une seule fenetre a la fois
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\DrSanteOutilFenetre', [ref]$createdNew)
if (-not $createdNew) { exit }

$titre  = 'Dr Santé outils'
$vert   = [System.Drawing.Color]::FromArgb(0, 128, 60)
$orange = [System.Drawing.Color]::FromArgb(200, 90, 0)
$rouge  = [System.Drawing.Color]::FromArgb(190, 0, 0)
$script:info = $null

function New-Ctrl([string]$Type, $Parent, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Texte) {
    $c = New-Object "System.Windows.Forms.$Type"
    $c.Location = New-Object System.Drawing.Point($X, $Y)
    if ($W) { $c.Width = $W }
    if ($H) { $c.Height = $H }
    if ($Texte) { $c.Text = $Texte }
    $Parent.Controls.Add($c)
    return $c
}

# --- Fenetre ---------------------------------------------------------------
$f = New-Object System.Windows.Forms.Form
$f.Text = $titre
$f.StartPosition = 'CenterScreen'
$f.FormBorderStyle = 'FixedSingle'
$f.MaximizeBox = $false
$f.ClientSize = New-Object System.Drawing.Size(640, 650)
$f.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$gras = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

# Prompt Heidi
$gp = New-Ctrl 'GroupBox' $f 12 10 616 195 'Prompt Heidi'
$lblEtat = New-Ctrl 'Label' $gp 15 26 586 44 ''
$lblEtat.Font = $gras
$lblVar = New-Ctrl 'Label' $gp 15 72 586 20 ''
$lblVar.ForeColor = [System.Drawing.Color]::DimGray
$btnCopier = New-Ctrl 'Button' $gp 15 98 240 40 'Copier le prompt Heidi'
$btnCopier.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$btnVoir = New-Ctrl 'Button' $gp 265 98 170 40 'Afficher le prompt'
$lblAide = New-Ctrl 'Label' $gp 15 146 586 42 "Dans Heidi : ouvrez votre modèle, sélectionnez tout l'ancien texte (Ctrl+A), collez le nouveau (Ctrl+V), puis enregistrez."

# Mises a jour
$gm = New-Ctrl 'GroupBox' $f 12 215 616 90 'Mises à jour'
$lblMaj = New-Ctrl 'Label' $gm 15 30 400 44 'Vérification en cours...'
$lblMaj.Font = $gras
$btnMaj = New-Ctrl 'Button' $gm 425 28 176 40 'Vérifier à nouveau'

# Ce poste
$gc = New-Ctrl 'GroupBox' $f 12 315 616 125 'Ce poste'
$lblPoste = New-Ctrl 'Label' $gc 15 26 586 46 ''
$btnDossier = New-Ctrl 'Button' $gc 15 76 210 36 'Ouvrir le dossier patient'
$btnReglages = New-Ctrl 'Button' $gc 235 76 210 36 'Modifier les réglages'

# Raccourcis
$gr = New-Ctrl 'GroupBox' $f 12 450 616 150 'Raccourcis dans Dr Santé'
$lblRac = New-Ctrl 'Label' $gr 15 24 586 120 ((@(
    "Ctrl + clic molette         consultation adulte" ,
    "Alt + clic molette          consultation enfant" ,
    "Maj + clic molette          courrier d'adressage" ,
    "Win + clic molette          ordonnance de kiné" ,
    "Ctrl + Alt + clic molette   ordonnance de soins infirmiers" ,
    "Ctrl + Alt + V              vider le dossier patient"
) -join "`n"))
$lblRac.Font = New-Object System.Drawing.Font('Consolas', 10)

$btnFermer = New-Ctrl 'Button' $f 528 610 100 32 'Fermer'
$btnFermer.DialogResult = 'Cancel'
$f.CancelButton = $btnFermer

# --- Etat du prompt --------------------------------------------------------
function Update-EtatPrompt {
    try {
        $var = 'sans étiquette carnet de santé'
        if ((Get-IniValue 'general' 'etiquette' '0') -eq '1') { $var = 'avec étiquette carnet de santé' }
        $lblVar.Text = "Version du prompt pour ce poste : $(Get-HeidiPromptVersion) ($var)"
        if (Test-HeidiPromptAJour) {
            $lblEtat.Text = [string][char]0x2714 + '  À jour : le dernier prompt copié correspond aux scripts installés.'
            $lblEtat.ForeColor = $vert
        }
        else {
            $lblEtat.Text = [string][char]0x26A0 + "  À faire : copiez le prompt et collez-le dans Heidi (nouvelle version, ou jamais copié sur ce poste)."
            $lblEtat.ForeColor = $orange
        }
        $btnCopier.Enabled = $true; $btnVoir.Enabled = $true
    }
    catch {
        $lblEtat.Text = "Prompt introuvable : relancez l'installation."
        $lblEtat.ForeColor = $rouge
        $btnCopier.Enabled = $false; $btnVoir.Enabled = $false
    }
}

$btnCopier.Add_Click({
    try {
        $null = Copy-HeidiPrompt
        Update-EtatPrompt
        [System.Windows.Forms.MessageBox]::Show(
            "Prompt copié.`n`nDans Heidi : ouvrez votre modèle, Ctrl+A puis Ctrl+V, et enregistrez.",
            $titre, 'OK', 'Information') | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Copie impossible : $($_.Exception.Message)", $titre, 'OK', 'Error') | Out-Null
    }
})

$btnVoir.Add_Click({
    $v = New-Object System.Windows.Forms.Form
    $v.Text = 'Prompt Heidi (lecture seule)'
    $v.StartPosition = 'CenterParent'
    $v.ClientSize = New-Object System.Drawing.Size(820, 620)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Multiline = $true; $t.ReadOnly = $true; $t.ScrollBars = 'Vertical'; $t.WordWrap = $true
    $t.Dock = 'Fill'
    $t.Font = New-Object System.Drawing.Font('Consolas', 10)
    $t.Text = Get-HeidiPromptText
    $t.SelectionStart = 0
    $v.Controls.Add($t)
    $null = $v.ShowDialog($f)
})

# --- Mises a jour ----------------------------------------------------------
function Update-EtatMaj {
    $lblMaj.Text = 'Vérification en cours...'
    $lblMaj.ForeColor = [System.Drawing.Color]::Black
    $btnMaj.Enabled = $false
    $f.Refresh()
    $script:info = $null
    try { $script:info = Get-UpdateInfo } catch { }
    if (-not $script:info) {
        $lblMaj.Text = 'Impossible de vérifier (connexion internet ?).'
        $lblMaj.ForeColor = $rouge
        $btnMaj.Text = 'Vérifier à nouveau'
    }
    elseif ($script:info.Disponible) {
        $lblMaj.Text = 'Une nouvelle version est disponible.'
        $lblMaj.ForeColor = $orange
        $btnMaj.Text = 'Installer la mise à jour'
    }
    else {
        $lblMaj.Text = [string][char]0x2714 + '  Les outils sont à jour.'
        $lblMaj.ForeColor = $vert
        $btnMaj.Text = 'Vérifier à nouveau'
    }
    $btnMaj.Enabled = $true
}

$btnMaj.Add_Click({
    if ($script:info -and $script:info.Disponible) {
        $f.Cursor = 'WaitCursor'
        $lblMaj.Text = 'Installation en cours...'
        $lblMaj.ForeColor = [System.Drawing.Color]::Black
        $f.Refresh()
        try {
            $null = Install-Update $script:info.Remote
            Restart-Outils -ParTache
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("La mise à jour a échoué : $($_.Exception.Message)", $titre, 'OK', 'Warning') | Out-Null
        }
        $f.Cursor = 'Default'
        Update-EtatPrompt
    }
    Update-EtatMaj
})

# --- Ce poste --------------------------------------------------------------
function Update-EtatPoste {
    $dp = Get-IniValue 'general' 'dossier_patient' '(non défini)'
    $dem = switch (Get-IniValue 'general' 'demarrage' '') {
        'tache'     { 'automatique, en mode administrateur' }
        'raccourci' { 'automatique (mode normal)' }
        default     { 'désactivé' }
    }
    $lblPoste.Text = "Dossier patient : $dp`nLancement à l'ouverture de Windows : $dem"
}

$btnDossier.Add_Click({
    $dp = Get-IniValue 'general' 'dossier_patient' ''
    if ($dp -and (Test-Path -LiteralPath $dp)) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $dp) }
    else { [System.Windows.Forms.MessageBox]::Show('Dossier patient introuvable.', $titre, 'OK', 'Warning') | Out-Null }
})

$btnReglages.Add_Click({
    $inst = Join-Path $script:AppDir 'Installer.ps1'
    $a = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Depot "{1}" -Branche "{2}"' -f $inst,
        (Get-IniValue 'depot' 'nom' ''), (Get-IniValue 'depot' 'branche' 'main')
    $tok = Get-Token
    if ($tok) { $a += (' -Token "{0}"' -f $tok) }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $a
    $f.Close()
})

# --- Affichage -------------------------------------------------------------
Update-EtatPrompt
Update-EtatPoste
$f.Add_Shown({ $f.Activate(); Update-EtatMaj })
try { $null = $f.ShowDialog() }
finally { $mutex.ReleaseMutex() }
