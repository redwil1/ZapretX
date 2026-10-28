@echo off
net stop ZapretRW >nul 2>&1
sc delete ZapretRW >nul 2>&1
"%~dp0killall.exe" winws.exe >nul 2>&1
"%~dp0killall.exe" winws2.exe >nul 2>&1
del "%~dp0active.txt" >nul 2>&1
