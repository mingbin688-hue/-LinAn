@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start.ps1" -Background -OpenApp
if errorlevel 1 pause
