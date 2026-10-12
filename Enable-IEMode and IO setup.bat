@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
set "PS=powershell.exe -NoProfile -ExecutionPolicy Bypass"
set "EDITIE_RUNID="

:: ==========================================================
:: Capture launcher context, then elevate (Administrator)
:: ==========================================================
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    set "EDITIE_CTX_OUT=%TEMP%\EditIE-runid.txt"
    set "EDITIE_CTX_ERR=%TEMP%\EditIE-runid.err"
    del "%EDITIE_CTX_OUT%" 2>nul
    del "%EDITIE_CTX_ERR%" 2>nul
    %PS% -File "%SCRIPT_DIR%scripts\Save-LaunchContext.ps1" 1>"%EDITIE_CTX_OUT%" 2>"%EDITIE_CTX_ERR%"
    if errorlevel 1 (
        echo Failed to save launch context. Elevation aborted.
        type "%EDITIE_CTX_ERR%" 2>nul
        pause
        EXIT /B 1
    )
    set /p EDITIE_RUNID=<"%EDITIE_CTX_OUT%"
    if not defined EDITIE_RUNID (
        echo Launch context file was empty. Elevation aborted.
        pause
        EXIT /B 1
    )
    %PS% -Command "Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList '/elevated','!EDITIE_RUNID!'"
    EXIT /B
)

IF /I "%~1"=="/elevated" (
    set "EDITIE_RUNID=%~2"
    if not defined EDITIE_RUNID (
        echo Missing run id for elevated session. Start the batch file without an elevated prompt.
        pause
        EXIT /B 1
    )
    goto MAIN
)

echo Run this tool from a non-elevated session so the launcher user can be captured.
echo Or use: "%~f0" /elevated {run-id}
pause
EXIT /B 1

:MAIN
title Automation Office Configuration - GUMS
color 0A

:MENU
cls
echo ==========================================================
echo.
echo      Guilan University of Medical Sciences
echo          Office Automation Configuration
echo.
echo ----------------------------------------------------------
echo.
echo Developer:
echo Sadegh Jafari
echo Roudsar - IT Department
echo.
echo ==========================================================
echo.
echo   [1] Microsoft Edge Settings
echo   [2] Internet Options Settings (Modern TLS)
echo   [2L] Internet Options Settings (Legacy TLS - WARNING)
echo   [3] Restore Previous Settings (from backup)
echo   [0] Exit
echo.
echo ==========================================================
echo.

set "choice="
set /p choice=Select an option: 

if /I "%choice%"=="1" goto EDGE
if /I "%choice%"=="2" goto INTERNET_MODERN
if /I "%choice%"=="2L" goto INTERNET_LEGACY
if /I "%choice%"=="3" goto RESET
if /I "%choice%"=="0" exit /B 0

goto MENU

:EDGE
cls
echo Applying Microsoft Edge Settings...
%PS% -File "%SCRIPT_DIR%scripts\Invoke-EdgeSettings.ps1" -RunId "%EDITIE_RUNID%"
echo.
pause
goto MENU

:INTERNET_MODERN
cls
echo Applying Internet Options Settings (Modern TLS)...
%PS% -File "%SCRIPT_DIR%scripts\Invoke-InternetSettings.ps1" -TlsMode Modern -RunId "%EDITIE_RUNID%"
echo.
pause
goto MENU

:INTERNET_LEGACY
cls
echo LEGACY TLS MODE - SSL 3.0 / TLS 1.0 / 1.1 (insecure)
%PS% -File "%SCRIPT_DIR%scripts\Invoke-InternetSettings.ps1" -TlsMode Legacy -RunId "%EDITIE_RUNID%"
echo.
pause
goto MENU

:RESET
cls
echo Restoring settings from backup...
%PS% -File "%SCRIPT_DIR%scripts\Invoke-RestoreSettings.ps1" -RunId "%EDITIE_RUNID%"
echo.
pause
goto MENU
