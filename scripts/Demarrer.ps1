# Lance a chaque ouverture de session Windows (ou par le raccourci
# "Rechercher une mise a jour" avec -Manuel) :
# 1) propose la mise a jour si une nouvelle version est publiee,
# 2) (re)lance le script AutoHotkey et la surveillance du dossier patient,
# 3) propose de copier le prompt Heidi s'il a change.
param([switch]$Manuel)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'Commun.ps1')
Add-Type -AssemblyName System.Windows.Forms
$titre = 'Dr Sante - mise a jour'

# --- 1) Mise a jour proposee ------------------------------------------------
$info = $null
try { $info = Get-UpdateInfo } catch { }   # hors ligne : silencieux

$majFaite = $false
$promptChange = $false
if ($info -and $info.Disponible) {
    $rep = [System.Windows.Forms.MessageBox]::Show(
        "Une nouvelle version des outils Dr Sante est disponible.`n`nL'installer maintenant ? (quelques secondes)",
        $titre, 'YesNo', 'Question')
    if ($rep -eq 'Yes') {
        try {
            $promptChange = Install-Update $info.Remote
            $majFaite = $true
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "La mise a jour a echoue : $($_.Exception.Message)`n`nElle sera reproposee au prochain demarrage.",
                $titre, 'OK', 'Warning') | Out-Null
        }
    }
}
elseif ($Manuel) {
    $msg = if ($info) { 'Vous avez deja la derniere version.' } else { 'Impossible de verifier les mises a jour (connexion internet ?).' }
    [System.Windows.Forms.MessageBox]::Show($msg, $titre, 'OK', 'Information') | Out-Null
}

# Recherche manuelle sans mise a jour : les outils tournent deja, rien a relancer
if ($Manuel -and -not $majFaite) { exit }

# --- 2) (Re)lancement des outils -------------------------------------------
$relance = $false
if ($Manuel -and (Get-IniValue 'general' 'demarrage' '') -eq 'tache') {
    # Relance en mode administrateur via la tache (pas de demande d'autorisation)
    try { Start-ScheduledTask -TaskName $script:NomTache -ErrorAction Stop; $relance = $true } catch { }
}

if (-not $relance) {
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

# --- 3) Prompt Heidi modifie -----------------------------------------------
if ($promptChange) {
    $rep = [System.Windows.Forms.MessageBox]::Show(
        "Le prompt Heidi a ete mis a jour.`n`nLe copier maintenant ? Il suffira ensuite de le coller (Ctrl+V) dans votre modele Heidi.",
        $titre, 'YesNo', 'Information')
    if ($rep -eq 'Yes') { $null = Copy-HeidiPrompt }
}
elseif ($majFaite -and $Manuel) {
    [System.Windows.Forms.MessageBox]::Show('Mise a jour installee.', $titre, 'OK', 'Information') | Out-Null
}
