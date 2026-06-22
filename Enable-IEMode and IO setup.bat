@echo off

:: ==========================================================
:: Run as Administrator
:: ==========================================================

NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    EXIT
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
echo   [2] Internet Options Settings
echo   [3] Restore Factory Settings
echo   [0] Exit
echo.
echo ==========================================================
echo.

set /p choice=Select an option: 

if "%choice%"=="1" goto EDGE
if "%choice%"=="2" goto INTERNET
if "%choice%"=="3" goto RESET
if "%choice%"=="0" exit

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

mkdir C:\IEMode 2>nul

(
echo ^<?xml version="1.0" encoding="utf-8"?^>
echo ^<site-list version="1"^>

echo ^<site url="http://at.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^<site url="https://at.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^<site url="http://oa1.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^<site url="http://oa2.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^<site url="http://oa3.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^<site url="http://oa4.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^<site url="https://oa1.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^<site url="https://oa2.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^<site url="https://oa3.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^<site url="https://oa4.gums.ac.ir/"^>
echo ^<compat-mode^>IE11^</compat-mode^>
echo ^<open-in^>IE11^</open-in^>
echo ^</site^>

echo ^</site-list^>
) > C:\IEMode\sites.xml

reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v InternetExplorerIntegrationLevel /t REG_DWORD /d 1 /f >nul

reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v InternetExplorerIntegrationSiteList /t REG_SZ /d "C:\IEMode\sites.xml" /f >nul

taskkill /F /IM msedge.exe >nul 2>&1

echo.
echo Microsoft Edge settings applied successfully.
echo.
pause
goto MENU

:: ==========================================================
:: INTERNET OPTIONS SETTINGS
:: ==========================================================

:INTERNET
cls

echo ==========================================================
echo.
echo Applying Internet Options Settings...
echo.
echo ==========================================================
echo.

:: HKCU settings must target the logged-on user (not the elevated admin account).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-InternetOptions.ps1" -Mode Apply

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Failed to apply per-user Internet Options settings.
    echo.
    pause
    goto MENU
)

:: ==========================================================
:: MACHINE-WIDE SSL/TLS (SCHANNEL)
:: ==========================================================
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" /v Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul

:: TLS 1.0
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul

:: TLS 1.1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul

:: TLS 1.2
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul

:: TLS 1.3 (Windows 10 1903+; ignored on Windows 8.1)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client" /v Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul

echo.
echo Internet Options settings applied successfully.
echo.
pause
goto MENU

:: ==========================================================
:: RESTORE FACTORY SETTINGS
:: ==========================================================

:RESET
cls

echo ==========================================================
echo.
echo Restoring Factory Settings...
echo.
echo ==========================================================
echo.

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v InternetExplorerIntegrationLevel /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v InternetExplorerIntegrationSiteList /f >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-InternetOptions.ps1" -Mode Reset

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Failed to restore per-user Internet Options settings.
    echo.
    pause
    goto MENU
)

reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DefaultSecureProtocols /f >nul 2>&1

reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DefaultSecureProtocols /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0" /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0" /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1" /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2" /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3" /f >nul 2>&1

echo.
echo Factory settings restored successfully.
echo.
pause
goto MENU