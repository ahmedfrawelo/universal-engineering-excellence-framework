Option Explicit

Dim shell, worker, command
Set shell = CreateObject("WScript.Shell")
worker = Replace(WScript.ScriptFullName, "run-auto-update.vbs", "auto-update.ps1")
command = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File """ & worker & """"
shell.Run command, 0, False
