# ===========================================================================
# Fenetre principale "Dr Santé outils" (menu Demarrer / bureau) :
#  - prompt Heidi : etat (a jour ou non par rapport aux scripts installes),
#    copie en un clic, affichage du texte ;
#  - mises a jour : verification et installation ;
#  - ce poste : dossier patient, demarrage, modification des reglages ;
#  - rappel des raccourcis clavier dans Dr Santé.
# ===========================================================================
. (Join-Path $PSScriptRoot 'Commun.ps1')
. (Join-Path $PSScriptRoot 'Interface.ps1')

# Une seule fenetre a la fois
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\DrSanteOutilFenetre', [ref]$createdNew)
if (-not $createdNew) { exit }

$titre = 'Dr Santé outils'
$script:info = $null

# --- Fenetre (2 colonnes : tient sur un portable a 125 %) -------------------
$f = New-Fenetre $titre 920 588
$version = ''
if (Test-Path -LiteralPath $script:ShaFile) { $version = (Get-Content -LiteralPath $script:ShaFile -Raw).Trim() }
if ($version.Length -gt 7) { $version = $version.Substring(0, 7) }
$null = Add-Entete $f 'Dr Santé outils' ('Heidi ' + [char]0x2192 + ' Dr Santé  ·  outils partagés entre confrères')

# Colonne gauche : prompt Heidi
$gp = Add-Carte $f 20 90 430 176 'Prompt Heidi'
$etatPrompt = Add-Etat $gp 16 42 398
$lblVar = Add-Ctrl 'Label' $gp 38 86 376 20 ''
$lblVar.ForeColor = $script:Theme.TexteDoux; $lblVar.Font = $script:PolicePetite
$btnCopier = Add-Bouton $gp 16 120 220 'Copier le prompt Heidi' -Primaire -H 38
$btnVoir = Add-Bouton $gp 246 120 168 'Afficher le prompt' -H 38

# Colonne gauche : mises a jour
$gm = Add-Carte $f 20 278 430 112 'Mises à jour'
$etatMaj = Add-Etat $gm 16 42 230
$btnMaj = Add-Bouton $gm 254 44 160 'Vérifier à nouveau'

# Colonne gauche : ce poste
$gc = Add-Carte $f 20 402 430 134 'Ce poste'
$lblPoste = Add-Ctrl 'Label' $gc 16 36 398 50 ''
$lblPoste.ForeColor = $script:Theme.TexteDoux
$btnDossier = Add-Bouton $gc 16 88 196 'Ouvrir le dossier patient'
$btnReglages = Add-Bouton $gc 220 88 194 'Modifier les réglages'

# Colonne droite : raccourcis
$gr = Add-Carte $f 470 90 430 446 'Raccourcis dans Dr Santé'
$script:lignesMemo = @()
$y = 52
foreach ($r in $script:RaccourcisDef) {
    $n = Add-Ctrl 'Label' $gr 16 ($y + 5) 180 22 $r.Nom
    $k = Add-Ctrl 'Label' $gr 200 $y 0 0 ''
    $k.AutoSize = $true
    $k.BackColor = $script:Theme.Touche
    $k.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
    $k.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)
    $script:lignesMemo += [pscustomobject]@{ Def = $r; Touche = $k }
    $y += 40
}
$lblAideRac = Add-Ctrl 'Label' $gr 16 ($y + 8) 398 80 ("Les imports et le menu des documents ne fonctionnent que dans la fenêtre Dr Santé. " +
    "Le menu des documents (kiné, soins infirmiers, certificats, imagerie) s'ouvre sous la souris : un clic colle le document choisi.")
$lblAideRac.ForeColor = $script:Theme.TexteDoux
$btnRac = Add-Bouton $gr 16 396 220 'Modifier les raccourcis'

# Pied de fenetre
$lblVersion = Add-Ctrl 'Label' $f 22 556 500 20 ''
$lblVersion.ForeColor = $script:Theme.TexteDoux; $lblVersion.Font = $script:PolicePetite
$lblVersion.Text = $script:Auteur
if ($version) { $lblVersion.Text += "  ·  version installée : $version" }
$btnFermer = Add-Bouton $f 790 548 110 'Fermer'
$btnFermer.DialogResult = 'Cancel'
$f.CancelButton = $btnFermer

# --- Etat du prompt --------------------------------------------------------
function Update-EtatPrompt {
    try {
        $var = 'sans étiquette carnet de santé'
        if ((Get-IniValue 'general' 'etiquette' '0') -eq '1') { $var = 'avec étiquette carnet de santé' }
        $lblVar.Text = "Version $(Get-HeidiPromptVersion), $var"
        if (Test-HeidiPromptAJour) {
            Set-Etat $etatPrompt 'ok' 'À jour : le prompt de Heidi correspond aux outils installés.'
        }
        else {
            Set-Etat $etatPrompt 'alerte' 'À faire : copiez le prompt et collez-le dans votre modèle Heidi.'
        }
        $btnCopier.Enabled = $true; $btnVoir.Enabled = $true
    }
    catch {
        Set-Etat $etatPrompt 'erreur' "Prompt introuvable : relancez l'installation."
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
    $v = New-Fenetre 'Prompt Heidi (lecture seule)' 820 560 -Dialogue
    $v.FormBorderStyle = 'Sizable'; $v.MaximizeBox = $true
    $t = New-Object System.Windows.Forms.TextBox
    $t.BorderStyle = 'None'; $t.BackColor = [System.Drawing.Color]::White
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
    Set-Etat $etatMaj 'neutre' 'Vérification en cours...'
    $btnMaj.Enabled = $false
    $f.Refresh()
    $script:info = $null
    try { $script:info = Get-UpdateInfo } catch { }
    if (-not $script:info) {
        Set-Etat $etatMaj 'erreur' 'Vérification impossible (connexion internet ?).' 
        $btnMaj.Text = 'Vérifier à nouveau'
    }
    elseif ($script:info.Disponible) {
        Set-Etat $etatMaj 'alerte' 'Une nouvelle version est disponible.' 
        $btnMaj.Text = 'Installer la mise à jour'
    }
    else {
        Set-Etat $etatMaj 'ok' 'Les outils sont à jour.' 
        $btnMaj.Text = 'Vérifier à nouveau'
    }
    $btnMaj.Enabled = $true
}

$btnMaj.Add_Click({
    if ($script:info -and $script:info.Disponible) {
        $f.Cursor = 'WaitCursor'
        Set-Etat $etatMaj 'neutre' 'Installation en cours...' 
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
    $lblPoste.ForeColor = $script:Theme.TexteDoux
    if ($dp -and -not (Test-DossierPatientSur $dp)) {
        $lblPoste.Text += "`n" + [char]0x26A0 + " Dossier non reconnu : nettoyage automatique désactivé."
        $lblPoste.ForeColor = $script:Theme.Orange
    }
    elseif (Test-DossierSynchronise $dp) {
        $lblPoste.Text += "`n" + [char]0x26A0 + " Dossier synchronisé sur internet (OneDrive, Dropbox...)."
        $lblPoste.ForeColor = $script:Theme.Orange
    }
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
    # SECURITE : plus de jeton en ligne de commande (visible par les autres
    # programmes) ; le depot est public.
    Start-Process -FilePath 'powershell.exe' -ArgumentList $a
    $f.Close()
})

# --- Raccourcis ------------------------------------------------------------
function Update-EtatRaccourcis {
    foreach ($l in $script:lignesMemo) {
        $l.Touche.Text = ConvertTo-TexteRaccourci (Get-Raccourci $l.Def.Cle)
    }
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
    $d = New-Fenetre 'Modifier les raccourcis' 640 360 -Dialogue

    $null = Add-Ctrl 'Label' $d 12 10 616 40 ("Cochez les touches à maintenir et choisissez la touche ou le bouton. " +
        "Les imports ne marchent que dans Dr Santé ; « Vider » marche partout. Réglage propre à ce poste.")

    $script:lignesRac = @()
    $y = 58
    foreach ($r in $script:RaccourcisDef) {
        $null = Add-Ctrl 'Label' $d 12 ($y + 4) 190 22 $r.Nom
        $l = [pscustomobject]@{
            Def  = $r
            Ctrl = Add-Ctrl 'CheckBox' $d 205 $y 55 26 'Ctrl'
            Alt  = Add-Ctrl 'CheckBox' $d 262 $y 50 26 'Alt'
            Maj  = Add-Ctrl 'CheckBox' $d 314 $y 52 26 'Maj'
            Win  = Add-Ctrl 'CheckBox' $d 368 $y 52 26 'Win'
            Liste = Add-Ctrl 'ComboBox' $d 425 $y 200 26 ''
        }
        $l.Liste.DropDownStyle = 'DropDownList'
        foreach ($t in $script:touches) { $null = $l.Liste.Items.Add($t.Texte) }
        $script:lignesRac += $l
        $y += 40
    }

    $btnDefaut = Add-Bouton $d 12 310 240 'Rétablir les valeurs par défaut'
    $btnOk     = Add-Bouton $d 400 310 110 'Enregistrer' -Primaire
    $btnAnn    = Add-Bouton $d 518 310 110 'Annuler'
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
