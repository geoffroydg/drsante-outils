# Lance a chaque ouverture de session Windows :
# 1) met a jour depuis GitHub (silencieux si hors ligne),
# 2) (re)lance le script AutoHotkey et la surveillance du dossier patient.

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'Commun.ps1')
Add-Type -AssemblyName System.Windows.Forms

$maj = $null
try { $maj = Update-AppFromDepot } catch { }

$ahk = Get-AhkExe
$ahkScript = Join-Path $script:AppDir 'scripts\DrSante.ahk'
$watcher   = Join-Path $script:AppDir 'scripts\Aplatir_dossier_patient.ps1'

if ($maj -and $maj.Updated) {
    Stop-ScriptProcess 'Aplatir_dossier_patient.ps1'
    Start-Sleep -Milliseconds 500
}

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

if ($maj -and $maj.PromptsChanged) {
    $rep = [System.Windows.Forms.MessageBox]::Show(
        "Le prompt Heidi a ete mis a jour.`n`nLe copier maintenant ? Il suffira ensuite de le coller dans votre modele Heidi.",
        'Dr Sante - mise a jour', 'YesNo', 'Information')
    if ($rep -eq 'Yes') { $null = Copy-HeidiPrompt }
}
