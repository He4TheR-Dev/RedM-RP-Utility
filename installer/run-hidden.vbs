Option Explicit
Dim sh, cmd, i
If WScript.Arguments.Count < 1 Then WScript.Quit 1

Function Quote(ByVal s)
  If InStr(s, " ") > 0 Then
    Quote = """" & Replace(s, """", """""") & """"
  Else
    Quote = s
  End If
End Function

cmd = Quote(WScript.Arguments.Item(0))
For i = 1 To WScript.Arguments.Count - 1
  cmd = cmd & " " & Quote(WScript.Arguments.Item(i))
Next

Set sh = CreateObject("WScript.Shell")
WScript.Quit sh.Run(cmd, 0, True)
