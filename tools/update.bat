@echo off
REM One-click updater for Meteora Raid Tool.
REM Edit the line below if you want to pin a specific repo here instead of relying on %METEORA_REPO%.
REM
REM Usage:
REM   1. Double-click this file, OR
REM   2. From the repo root:  tools\update.bat
REM
REM The first run will detect your WoW install and cache the path to %USERPROFILE%\.meteora-raid-tool.json.

setlocal
set "SCRIPT_DIR=%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Install-MeteoraRaidTool.ps1" %*
set EXITCODE=%ERRORLEVEL%

if not "%~1"=="--quiet" (
    echo.
    pause
)
exit /b %EXITCODE%
