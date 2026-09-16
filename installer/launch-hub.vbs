Option Explicit
Dim sh, fso, dir, ui, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
ui = dir & "\hub-ui.ps1"
If Not fso.FileExists(ui) Then
  MsgBox "hub-ui.ps1 introuvable. Relance l'installeur Vocal Roleplay.", vbCritical, "Vocal Roleplay"
  WScript.Quit 1
End If
cmd = "powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ui & """"
sh.Run cmd, 0, False
WScript.Quit 0
