@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
set "PS=powershell.exe -NoProfile -ExecutionPolicy Bypass"

:: ==========================================================
:: Capture launcher context, then elevate (Administrator)
:: ==========================================================
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    %PS% -File "%SCRIPT_DIR%scripts\Save-LaunchContext.ps1"
    %PS% -Command "Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList '/elevated'"
    EXIT /B
)

IF /I NOT "%~1"=="/elevated" (
    %PS% -File "%SCRIPT_DIR%scripts\Save-LaunchContext.ps1"
)

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

:: ==========================================================
:: EDGE SETTINGS
:: ==========================================================

:EDGE
cls
echo ==========================================================
echo.
echo Applying Microsoft Edge Settings...
echo.
echo ==========================================================
echo.
%PS% -File "%SCRIPT_DIR%scripts\Invoke-EdgeSettings.ps1"
echo.
pause
goto MENU

:: ==========================================================
:: INTERNET OPTIONS (MODERN)
:: ==========================================================

:INTERNET_MODERN
cls
echo ==========================================================
echo.
echo Applying Internet Options Settings (Modern TLS)...
echo.
echo ==========================================================
echo.
%PS% -File "%SCRIPT_DIR%scripts\Invoke-InternetSettings.ps1" -TlsMode Modern
echo.
pause
goto MENU

:: ==========================================================
:: INTERNET OPTIONS (LEGACY)
:: ==========================================================

:INTERNET_LEGACY
cls
echo ==========================================================
echo.
echo LEGACY TLS MODE - SSL 3.0 / TLS 1.0 / 1.1 (insecure)
echo.
echo ==========================================================
echo.
%PS% -File "%SCRIPT_DIR%scripts\Invoke-InternetSettings.ps1" -TlsMode Legacy
echo.
pause
goto MENU

:: ==========================================================
:: RESTORE FROM BACKUP
:: ==========================================================

:RESET
cls
echo ==========================================================
echo.
echo Restoring settings from backup...
echo.
echo ==========================================================
echo.
%PS% -File "%SCRIPT_DIR%scripts\Invoke-RestoreSettings.ps1"
echo.
pause
goto MENU
