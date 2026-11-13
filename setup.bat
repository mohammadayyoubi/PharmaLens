@echo off
rem PharmaLens first-time setup: double-click this file.
rem It checks Flutter, creates the private key files and downloads the packages.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\setup.ps1" %*
echo.
pause
