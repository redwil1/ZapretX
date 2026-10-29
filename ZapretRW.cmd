@echo off
rem Double-click launcher: Windows opens .ps1 files in Notepad by default.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0ZapretRW.ps1"
