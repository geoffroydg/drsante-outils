' Lance un script PowerShell sans fenetre. Usage : wscript Lancer_silencieux.vbs "NomDuScript.ps1"
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
dossier = fso.GetParentFolderName(WScript.ScriptFullName)
If WScript.Arguments.Count > 0 Then
    cible = WScript.Arguments(0)
Else
    cible = "Demarrer.ps1"
End If
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dossier & "\" & cible & """", 0, False
