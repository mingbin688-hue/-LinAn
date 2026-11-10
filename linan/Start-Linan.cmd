@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start.ps1" -Background -OpenBrowser
if errorlevel 1 pause
