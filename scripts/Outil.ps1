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
$f.ClientSize = New-Object System.Drawing.Size(640, 732)
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
$gr = New-Ctrl 'GroupBox' $f 12 450 616 232 'Raccourcis dans Dr Santé'
$lblRac = New-Ctrl 'Label' $gr 15 24 586 156 ''
$lblRac.Font = New-Object System.Drawing.Font('Consolas', 10)
$btnRac = New-Ctrl 'Button' $gr 15 184 240 36 'Modifier les raccourcis'

$btnFermer = New-Ctrl 'Button' $f 528 692 100 32 'Fermer'
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

# --- Raccourcis ------------------------------------------------------------
function Update-EtatRaccourcis {
    $lignes = foreach ($r in $script:RaccourcisDef) {
        '{0,-27}{1}' -f $r.Nom, (ConvertTo-TexteRaccourci (Get-Raccourci $r.Cle))
    }
    $lblRac.Text = ($lignes -join "`n")
}

# Remplit une ligne de la fenetre de modification
function Set-LigneRac($l, [string]$Ahk) {
    $s = Split-Raccourci $Ahk
    $l.Ctrl.Checked = $s.Ctrl; $l.Alt.Checked = $s.Alt
    $l.Maj.Checked = $s.Maj;   $l.Win.Checked = $s.Win
    $idx = -1
    for ($i = 0; $i -lt $script:touches.Count; $i++) { if ($script:touches[$i].Ahk -eq $s.Touche) { $idx = $i; break } }
    if ($idx -lt 0) {
        $s2 = Split-Raccourci $l.Def.Defaut
        for ($i = 0; $i -lt $script:touches.Count; $i++) { if ($script:touches[$i].Ahk -eq $s2.Touche) { $idx = $i; break } }
    }
    $l.Liste.SelectedIndex = $idx
}

# Fenetre de modification (enregistre dans config.ini, propre a ce poste)
function Show-EditeurRaccourcis {
    $script:touches = Get-TouchesRaccourci
    $d = New-Object System.Windows.Forms.Form
    $d.Text = 'Modifier les raccourcis'
    $d.StartPosition = 'CenterParent'
    $d.FormBorderStyle = 'FixedDialog'
    $d.MaximizeBox = $false; $d.MinimizeBox = $false
    $d.ClientSize = New-Object System.Drawing.Size(640, 480)
    $d.Font = $f.Font

    $null = New-Ctrl 'Label' $d 12 10 616 40 ("Cochez les touches à maintenir et choisissez la touche ou le bouton. " +
        "Les imports ne marchent que dans Dr Santé ; « Vider » marche partout. Réglage propre à ce poste.")

    $script:lignesRac = @()
    $y = 58
    foreach ($r in $script:RaccourcisDef) {
        $null = New-Ctrl 'Label' $d 12 ($y + 4) 190 22 $r.Nom
        $l = [pscustomobject]@{
            Def  = $r
            Ctrl = New-Ctrl 'CheckBox' $d 205 $y 55 26 'Ctrl'
            Alt  = New-Ctrl 'CheckBox' $d 262 $y 50 26 'Alt'
            Maj  = New-Ctrl 'CheckBox' $d 314 $y 52 26 'Maj'
            Win  = New-Ctrl 'CheckBox' $d 368 $y 52 26 'Win'
            Liste = New-Ctrl 'ComboBox' $d 425 $y 200 26 ''
        }
        $l.Liste.DropDownStyle = 'DropDownList'
        foreach ($t in $script:touches) { $null = $l.Liste.Items.Add($t.Texte) }
        $script:lignesRac += $l
        $y += 40
    }

    $btnDefaut = New-Ctrl 'Button' $d 12 430 240 36 'Rétablir les valeurs par défaut'
    $btnOk     = New-Ctrl 'Button' $d 400 430 110 36 'Enregistrer'
    $btnAnn    = New-Ctrl 'Button' $d 518 430 110 36 'Annuler'
    $btnAnn.DialogResult = 'Cancel'
    $d.CancelButton = $btnAnn
    $script:dlgRac = $d

    foreach ($l in $script:lignesRac) { Set-LigneRac $l (Get-Raccourci $l.Def.Cle) }

    $btnDefaut.Add_Click({
        foreach ($l in $script:lignesRac) { Set-LigneRac $l $l.Def.Defaut }
    })

    $btnOk.Add_Click({
        $vals = @{}; $erreurs = @(); $vus = @{}
        foreach ($l in $script:lignesRac) {
            $nom = $l.Def.Nom
            if ($l.Liste.SelectedIndex -lt 0) { $erreurs += "$nom : choisissez une touche."; continue }
            $t = $script:touches[$l.Liste.SelectedIndex]
            $nbMod = @($l.Ctrl.Checked, $l.Alt.Checked, $l.Maj.Checked, $l.Win.Checked | Where-Object { $_ }).Count
            if ($t.Type -eq 'souris' -and $nbMod -lt 1) {
                $erreurs += "$nom : cochez au moins une touche (Ctrl, Alt, Maj ou Win) avec un bouton de souris."
            }
            if ($t.Type -eq 'lettre') {
                if ($l.Win.Checked) { $erreurs += "$nom : Win + lettre ou chiffre est réservé par Windows." }
                elseif ($nbMod -lt 2) { $erreurs += "$nom : avec une lettre ou un chiffre, cochez au moins deux touches (ex. Ctrl + Alt)." }
            }
            $v = Join-Raccourci $l.Ctrl.Checked $l.Alt.Checked $l.Maj.Checked $l.Win.Checked $t.Ahk
            if ($vus.ContainsKey($v)) { $erreurs += "$nom : même raccourci que « $($vus[$v]) »." }
            else { $vus[$v] = $nom }
            $vals[$l.Def.Cle] = $v
        }
        if ($erreurs.Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show(($erreurs -join "`n"), 'Raccourcis non enregistrés', 'OK', 'Warning') | Out-Null
            return
        }
        try {
            foreach ($k in $vals.Keys) { Set-IniValue 'raccourcis' $k $vals[$k] }
            Restart-Outils -ParTache
            $script:dlgRac.DialogResult = 'OK'
            $script:dlgRac.Close()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Enregistrement impossible : $($_.Exception.Message)", $titre, 'OK', 'Error') | Out-Null
        }
    })

    if ($d.ShowDialog($f) -eq 'OK') {
        Update-EtatRaccourcis
        [System.Windows.Forms.MessageBox]::Show('Raccourcis enregistrés et outils relancés : ils sont actifs tout de suite.',
            $titre, 'OK', 'Information') | Out-Null
    }
    $d.Dispose()
}

$btnRac.Add_Click({ Show-EditeurRaccourcis })

# --- Affichage -------------------------------------------------------------
Update-EtatPrompt
Update-EtatPoste
Update-EtatRaccourcis
$f.Add_Shown({ $f.Activate(); Update-EtatMaj })
try { $null = $f.ShowDialog() }
finally { $mutex.ReleaseMutex() }
