' Lance un script PowerShell sans fenetre. Usage : wscript Lancer_silencieux.vbs "NomDuScript.ps1" [arguments...]
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
dossier = fso.GetParentFolderName(WScript.ScriptFullName)
If WScript.Arguments.Count > 0 Then
    cible = WScript.Arguments(0)
Else
    cible = "Demarrer.ps1"
End If
extra = ""
For i = 1 To WScript.Arguments.Count - 1
    extra = extra & " " & WScript.Arguments(i)
Next
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dossier & "\" & cible & """" & extra, 0, False
