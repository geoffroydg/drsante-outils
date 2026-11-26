# ===========================================================================
# Apparence commune des fenetres (Dr Santé outils, installation) :
#  - affichage net sur les ecrans agrandis a 125 % / 150 % (sinon Windows
#    etire la fenetre comme une image : texte flou) ;
#  - couleurs, bandeau, cartes, boutons, icone.
# Utilisation : . "$PSScriptRoot\Interface.ps1"  (avant de creer une fenetre)
# ===========================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Nettete (DPI) : a faire AVANT la premiere fenetre ----------------------
if (-not ('DrSante.Dpi' -as [type])) {
    Add-Type -Namespace DrSante -Name Dpi -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shcore.dll")]
public static extern int SetProcessDpiAwareness(int value);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDPIAware();
'@
}
try { $null = [DrSante.Dpi]::SetProcessDpiAwareness(1) }   # Windows 8.1 et +
catch { try { $null = [DrSante.Dpi]::SetProcessDPIAware() } catch { } }
[System.Windows.Forms.Application]::EnableVisualStyles()
try { [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false) } catch { }

# --- Couleurs ---------------------------------------------------------------
function New-Couleur([string]$Hex) { [System.Drawing.ColorTranslator]::FromHtml($Hex) }
$script:Theme = @{
    Primaire      = New-Couleur '#0F5C8C'   # bleu medical
    PrimaireFonce = New-Couleur '#0B4669'
    Fond          = New-Couleur '#F3F5F8'
    Carte         = [System.Drawing.Color]::White
    Bordure       = New-Couleur '#DCE1E7'
    Texte         = New-Couleur '#1F2933'
    TexteDoux     = New-Couleur '#5F6B7A'
    Vert          = New-Couleur '#1E8E4E'
    Orange        = New-Couleur '#C26A00'
    Rouge         = New-Couleur '#C0392B'
    Touche        = New-Couleur '#EEF1F5'
}
$script:Police       = New-Object System.Drawing.Font('Segoe UI', 9.75)
$script:PoliceGras   = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5)
$script:PoliceTitre  = New-Object System.Drawing.Font('Segoe UI Semibold', 16)
$script:PolicePetite = New-Object System.Drawing.Font('Segoe UI', 8.75)

# --- Icone (carre bleu arrondi, croix blanche) -------------------------------
function Get-IconeDrSante {
    if ($script:IconeDrSante) { return $script:IconeDrSante }
    $bmp = New-Object System.Drawing.Bitmap 64, 64
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 14
    $p.AddArc(2, 2, $r, $r, 180, 90); $p.AddArc(62 - $r, 2, $r, $r, 270, 90)
    $p.AddArc(62 - $r, 62 - $r, $r, $r, 0, 90); $p.AddArc(2, 62 - $r, $r, $r, 90, 90)
    $p.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush $script:Theme.Primaire), $p)
    $blanc = [System.Drawing.Brushes]::White
    $g.FillRectangle($blanc, 26, 14, 12, 36)
    $g.FillRectangle($blanc, 14, 26, 36, 12)
    $g.Dispose()
    $script:IconeDrSante = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    return $script:IconeDrSante
}

# --- Fenetre ----------------------------------------------------------------
# Les positions sont donnees pour un ecran a 100 % : AutoScaleMode Dpi les
# agrandit automatiquement (125 %, 150 %...).
function New-Fenetre([string]$Titre, [int]$Largeur, [int]$Hauteur, [switch]$Dialogue) {
    $f = New-Object System.Windows.Forms.Form
    $f.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $f.AutoScaleMode = 'Dpi'
    $f.Text = $Titre
    $f.Font = $script:Police
    $f.BackColor = $script:Theme.Fond
    $f.ForeColor = $script:Theme.Texte
    $f.ClientSize = New-Object System.Drawing.Size($Largeur, $Hauteur)
    $f.FormBorderStyle = 'FixedSingle'
    $f.MaximizeBox = $false
    if ($Dialogue) { $f.MinimizeBox = $false; $f.ShowInTaskbar = $false; $f.StartPosition = 'CenterParent' }
    else { $f.StartPosition = 'CenterScreen' }
    try { $f.Icon = Get-IconeDrSante } catch { }
    return $f
}

function Add-Ctrl([string]$Type, $Parent, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Texte) {
    $c = New-Object "System.Windows.Forms.$Type"
    $c.Location = New-Object System.Drawing.Point($X, $Y)
    if ($W) { $c.Width = $W }
    if ($H) { $c.Height = $H }
    if ($Texte) { $c.Text = $Texte }
    $Parent.Controls.Add($c)
    return $c
}

# Bandeau bleu en haut de la fenetre
function Add-Entete($Form, [string]$Titre, [string]$SousTitre) {
    $p = Add-Ctrl 'Panel' $Form 0 0 $Form.ClientSize.Width 72 ''
    $p.BackColor = $script:Theme.Primaire
    $p.Anchor = 'Top, Left, Right'
    $t = Add-Ctrl 'Label' $p 22 10 ($Form.ClientSize.Width - 44) 32 $Titre
    $t.Font = $script:PoliceTitre; $t.ForeColor = [System.Drawing.Color]::White
    $s = Add-Ctrl 'Label' $p 24 43 ($Form.ClientSize.Width - 44) 20 $SousTitre
    $s.Font = $script:Police; $s.ForeColor = New-Couleur '#D6E6F2'
    return $p
}

# Carte blanche avec titre ; renvoie le panneau (y placer les controles)
function Add-Carte($Parent, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Titre) {
    $c = Add-Ctrl 'Panel' $Parent $X $Y $W $H ''
    $c.BackColor = $script:Theme.Carte
    $c.Add_Paint({
        param($s, $e)
        $pen = New-Object System.Drawing.Pen $script:Theme.Bordure
        $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
        $pen.Dispose()
    })
    if ($Titre) {
        $t = Add-Ctrl 'Label' $c 16 12 ($W - 32) 22 $Titre
        $t.Font = $script:PoliceGras; $t.ForeColor = $script:Theme.Texte
    }
    return $c
}

# Bouton plat : -Primaire = bleu plein ; sinon blanc a bordure grise
function Add-Bouton($Parent, [int]$X, [int]$Y, [int]$W, [string]$Texte, [switch]$Primaire, [int]$H = 34) {
    $b = Add-Ctrl 'Button' $Parent $X $Y $W $H $Texte
    $b.FlatStyle = 'Flat'
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.UseVisualStyleBackColor = $false
    if ($Primaire) {
        $b.BackColor = $script:Theme.Primaire; $b.ForeColor = [System.Drawing.Color]::White
        $b.FlatAppearance.BorderSize = 0
        $b.FlatAppearance.MouseOverBackColor = $script:Theme.PrimaireFonce
        $b.Font = $script:PoliceGras
    }
    else {
        $b.BackColor = [System.Drawing.Color]::White; $b.ForeColor = $script:Theme.Texte
        $b.FlatAppearance.BorderColor = $script:Theme.Bordure
        $b.FlatAppearance.MouseOverBackColor = $script:Theme.Touche
    }
    return $b
}

# Pastille de couleur + texte d'etat ; Set-Etat la met a jour
function Add-Etat($Parent, [int]$X, [int]$Y, [int]$W) {
    $p = Add-Ctrl 'Label' $Parent $X $Y 20 24 ([string][char]0x25CF)
    $p.Font = New-Object System.Drawing.Font('Segoe UI', 12)
    $t = Add-Ctrl 'Label' $Parent ($X + 22) ($Y + 2) ($W - 22) 40 ''
    $t.Font = $script:PoliceGras
    return [pscustomobject]@{ Pastille = $p; Texte = $t }
}

function Set-Etat($Etat, [string]$Niveau, [string]$Texte) {
    $c = switch ($Niveau) {
        'ok'     { $script:Theme.Vert }
        'alerte' { $script:Theme.Orange }
        'erreur' { $script:Theme.Rouge }
        default  { $script:Theme.TexteDoux }
    }
    $Etat.Pastille.ForeColor = $c
    $Etat.Texte.Text = $Texte
    $Etat.Texte.ForeColor = $script:Theme.Texte
}
