# Cree (ou supprime) la tache planifiee qui lance les outils en mode
# administrateur a l'ouverture de session, sans demande d'autorisation.
# Lance par Installer.ps1, deja en mode administrateur (une seule autorisation).
param(
    [Parameter(Mandatory = $true)][string]$Utilisateur,
    [string]$Vbs = '',
    [switch]$Supprimer
)

$ErrorActionPreference = 'Stop'
$nom = 'Dr Sante outils'

try {
    if ($Supprimer) {
        Unregister-ScheduledTask -TaskName $nom -Confirm:$false -ErrorAction SilentlyContinue
        exit 0
    }
    if (-not $Vbs) { exit 2 }

    $action = New-ScheduledTaskAction -Execute 'wscript.exe' `
        -Argument ('"{0}" "Demarrer.ps1"' -f $Vbs) -WorkingDirectory (Split-Path -Parent $Vbs)
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $Utilisateur
    $trigger.Delay = 'PT20S'   # laisse le temps au reseau de demarrer
    $principal = New-ScheduledTaskPrincipal -UserId $Utilisateur -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $nom -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    exit 0
}
catch { exit 1 }
