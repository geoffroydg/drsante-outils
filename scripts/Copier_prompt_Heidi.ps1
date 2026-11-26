# Copie le prompt Heidi a jour dans le presse-papiers (variante adaptee a ce PC).
Add-Type -AssemblyName System.Windows.Forms
. (Join-Path $PSScriptRoot 'Commun.ps1')

try {
    $avec = Copy-HeidiPrompt
    $variante = 'sans etiquette carnet de sante'
    if ($avec) { $variante = 'avec etiquette carnet de sante' }
    [System.Windows.Forms.MessageBox]::Show(
        "Prompt Heidi copie ($variante).`n`nCollez-le (Ctrl+V) dans votre modele Heidi, a la place de l'ancien.",
        'Dr Sante - prompt Heidi', 'OK', 'Information') | Out-Null
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Impossible de copier le prompt : $($_.Exception.Message)",
        'Dr Sante - prompt Heidi', 'OK', 'Error') | Out-Null
}
