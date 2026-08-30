' dsh-launch.vbs - launch the DSH web server fully hidden (no console flash),
' then open the GUI in the default browser once the server responds.
' Portable: the repo root is derived from this file's own location, so the
' same script works from any checkout directory (see scripts/deploy.ps1).
' Invoked by wscript.exe from the startup folder, the desktop / start-menu
' shortcuts, and (with the "server" argument) by the logon Run-key entry.
'
' Arguments (optional):
'   (none)      full mode: ensure server running, then open the browser
'   server      server-only: ensure server running, never open the browser
'   open        open-only: never start the server, wait for it, open the browser
Option Explicit

Dim fso, shell, scriptDir, repoRoot, nodeCmd, mode
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
repoRoot = fso.GetParentFolderName(scriptDir)

mode = "full"
If WScript.Arguments.Count > 0 Then mode = LCase(WScript.Arguments(0))

' node.exe is resolved from PATH (deploy.ps1 ensures Node.js is on PATH)
If mode = "server" Then
    nodeCmd = "node.exe """ & scriptDir & "\dsh-launch.js"" --server-only"
ElseIf mode = "open" Then
    nodeCmd = "node.exe """ & scriptDir & "\dsh-launch.js"" --open-only"
Else
    nodeCmd = "node.exe """ & scriptDir & "\dsh-launch.js"""
End If

' window style 0 = hidden; False = do not wait for the script to finish
shell.Run nodeCmd, 0, False
