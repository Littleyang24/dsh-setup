' dsh-launch.vbs - launch the DSH web server fully hidden (no console flash),
' then open the GUI in the default browser once the server responds.
' Invoked by wscript.exe from the startup folder and the desktop / start-menu
' shortcuts, and (with the "server" argument) by the logon scheduled task.
'
' Arguments (optional):
'   (none)      full mode: ensure server running, then open the browser
'   server      server-only: ensure server running, never open the browser
'   open        open-only: never start the server, wait for it, open the browser
Option Explicit

Dim shell, nodeCmd, mode
Set shell = CreateObject("WScript.Shell")

mode = "full"
If WScript.Arguments.Count > 0 Then mode = LCase(WScript.Arguments(0))

If mode = "server" Then
    nodeCmd = """D:\Program Files\nodejs\node.exe"" ""D:\DSH\scripts\dsh-launch.js"" --server-only"
ElseIf mode = "open" Then
    nodeCmd = """D:\Program Files\nodejs\node.exe"" ""D:\DSH\scripts\dsh-launch.js"" --open-only"
Else
    nodeCmd = """D:\Program Files\nodejs\node.exe"" ""D:\DSH\scripts\dsh-launch.js"""
End If

' window style 0 = hidden; False = do not wait for the script to finish
shell.Run nodeCmd, 0, False
