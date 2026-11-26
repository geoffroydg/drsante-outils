@echo off
rem Publie les modifications sur GitHub (cree le depot la premiere fois).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Publier.ps1" %*
echo.
pause
