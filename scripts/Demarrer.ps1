# Lance a chaque ouverture de session Windows :
# 1) propose la mise a jour si une nouvelle version est publiee,
# 2) (re)lance le script AutoHotkey et la surveillance du dossier patient,
# 3) si le prompt Heidi a change, propose d'ouvrir "Dr Sante outils" pour le copier.
# -Manuel : ancienne recherche manuelle -> ouvre simplement la fenetre de l'outil.
param([switch]$Manuel)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'Commun.ps1')
Add-Type -AssemblyName System.Windows.Forms
$titre = 'Dr Sante - mise a jour'

if ($Manuel) { Open-Outil; exit }

# --- 1) Mise a jour proposee ------------------------------------------------
$info = $null
try { $info = Get-UpdateInfo } catch { }   # hors ligne : silencieux

$promptChange = $false
if ($info -and $info.Disponible) {
    $rep = [System.Windows.Forms.MessageBox]::Show(
        "Une nouvelle version des outils Dr Sante est disponible.`n`nL'installer maintenant ? (quelques secondes)",
        $titre, 'YesNo', 'Question')
    if ($rep -eq 'Yes') {
        try { $promptChange = Install-Update $info.Remote }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "La mise a jour a echoue : $($_.Exception.Message)`n`nElle sera reproposee au prochain demarrage.",
                $titre, 'OK', 'Warning') | Out-Null
        }
    }
}

# --- 2) (Re)lancement des outils -------------------------------------------
Restart-Outils

# --- 3) Prompt Heidi a mettre a jour dans Heidi ----------------------------
if ($promptChange) {
    $rep = [System.Windows.Forms.MessageBox]::Show(
        "Le prompt Heidi a change avec cette mise a jour : il faut le remplacer dans votre modele Heidi.`n`nOuvrir Dr Sante outils pour le copier ?",
        $titre, 'YesNo', 'Information')
    if ($rep -eq 'Yes') { Open-Outil }
}
