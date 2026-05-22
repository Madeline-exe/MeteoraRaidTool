@echo off
REM ====================================================================
REM  Meteora Raid Tool — one-click updater for Windows
REM  Just double-click this file. No other files needed.
REM
REM  What it does:
REM    1. Downloads the latest installer script from GitHub
REM    2. Runs it — installer downloads latest Release ZIP and copies
REM       MeteoraRaidTool into your WoW Classic AddOns folder
REM    3. Caches the WoW path so subsequent runs are silent and fast
REM ====================================================================

setlocal EnableDelayedExpansion
chcp 65001 > nul 2>&1

echo.
echo === Meteora Raid Tool updater ===
echo.

set "INSTALLER=%TEMP%\MeteoraRaidTool-installer.ps1"
set "INSTALLER_URL=https://raw.githubusercontent.com/Madeline-exe/MeteoraRaidTool/main/tools/Install-MeteoraRaidTool.ps1"

echo Fetching installer from GitHub...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; try { Invoke-WebRequest -Uri '%INSTALLER_URL%' -OutFile '%INSTALLER%' -UseBasicParsing; Write-Host 'OK' -ForegroundColor Green } catch { Write-Host ('Failed: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"

if errorlevel 1 (
    echo.
    echo Could not download the installer. Check your internet connection.
    echo.
    pause
    exit /b 1
)

echo.
echo Running installer...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALLER%" %*
set "EXITCODE=%ERRORLEVEL%"

del "%INSTALLER%" 2> nul

echo.
if "%EXITCODE%"=="0" (
    echo === Done. Type /reload in WoW to apply. ===
) else (
    echo === Failed with exit code %EXITCODE%. See messages above. ===
)
echo.
pause
exit /b %EXITCODE%
