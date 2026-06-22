@echo off

set SCRIPT_VERSION=1.0.0
set TELEMETRY_URL=http://185.252.200.112:8080/api/install
set TELEMETRY_PENDING=C:\IEMode\telemetry_pending.json

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

call :TELEMETRY_INIT

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

:: ==========================================================
:: TRUSTED SITES
:: ==========================================================

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\at" /v http /t REG_DWORD /d 2 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\at" /v https /t REG_DWORD /d 2 /f >nul

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\oa1" /v http /t REG_DWORD /d 2 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\oa1" /v https /t REG_DWORD /d 2 /f >nul

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\oa2" /v http /t REG_DWORD /d 2 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\oa2" /v https /t REG_DWORD /d 2 /f >nul

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\oa3" /v http /t REG_DWORD /d 2 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\oa3" /v https /t REG_DWORD /d 2 /f >nul

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\oa4" /v http /t REG_DWORD /d 2 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\oa4" /v https /t REG_DWORD /d 2 /f >nul

:: ==========================================================
:: DISABLE POPUP BLOCKER
:: ==========================================================

reg add "HKCU\Software\Microsoft\Internet Explorer\New Windows" /v PopupMgr /t REG_DWORD /d 0 /f >nul

:: ==========================================================
:: ENABLE SSL/TLS CHECKBOXES
:: ==========================================================

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v SecureProtocols /t REG_DWORD /d 10976 /f >nul

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DefaultSecureProtocols /t REG_DWORD /d 10976 /f >nul

reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DefaultSecureProtocols /t REG_DWORD /d 10976 /f >nul

:: SSL 3.0
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

:: TLS 1.3
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client" /v Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul

:: ==========================================================
:: DISABLE CERTIFICATE CHECKS
:: ==========================================================

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing" /v State /t REG_DWORD /d 146432 /f >nul

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

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir" /f >nul 2>&1

reg add "HKCU\Software\Microsoft\Internet Explorer\New Windows" /v PopupMgr /t REG_DWORD /d 1 /f >nul

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v SecureProtocols /t REG_DWORD /d 2688 /f >nul

reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DefaultSecureProtocols /f >nul 2>&1

reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DefaultSecureProtocols /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0" /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0" /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1" /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2" /f >nul 2>&1

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3" /f >nul 2>&1

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing" /v State /t REG_DWORD /d 146944 /f >nul

echo.
echo Factory settings restored successfully.
echo.
pause
goto MENU

:: ==========================================================
:: OPT-IN INSTALLATION TELEMETRY
:: ==========================================================

:TELEMETRY_INIT
reg query "HKCU\Software\GUMS\EditIE" /v TelemetryOptIn >nul 2>&1
if %ERRORLEVEL% NEQ 0 goto ASK_TELEMETRY
goto TELEMETRY_MAYBE_SEND

:ASK_TELEMETRY
cls
echo ==========================================================
echo.
echo   Organizational Install Statistics (Optional)
echo.
echo   To help the IT department track how many systems
echo   have installed this tool, you may allow sending a
echo   one-time report to the internal server when online.
echo.
echo   Data sent: computer name, Windows version, software version
echo   Sender IP is recorded automatically by the server.
echo.
echo   [1] Yes, I agree
echo   [2] No, do not send
echo.
echo ==========================================================
echo.
set /p telemetry_choice=Select an option: 

if "%telemetry_choice%"=="1" (
    for /f %%i in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString()"') do set INSTALL_ID=%%i
    reg add "HKCU\Software\GUMS\EditIE" /v TelemetryOptIn /t REG_DWORD /d 1 /f >nul
    reg add "HKCU\Software\GUMS\EditIE" /v InstallId /t REG_SZ /d "%INSTALL_ID%" /f >nul
    call :TELEMETRY_SAVE_PENDING
) else (
    reg add "HKCU\Software\GUMS\EditIE" /v TelemetryOptIn /t REG_DWORD /d 0 /f >nul
)

:TELEMETRY_MAYBE_SEND
reg query "HKCU\Software\GUMS\EditIE" /v TelemetryOptIn | find "0x1" >nul
if %ERRORLEVEL% NEQ 0 exit /b

reg query "HKCU\Software\GUMS\EditIE" /v InstallReported >nul 2>&1
if %ERRORLEVEL% EQU 0 exit /b

if not exist "C:\IEMode\telemetry_pending.json" call :TELEMETRY_SAVE_PENDING

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$pendingPath='%TELEMETRY_PENDING%';" ^
  "$url='%TELEMETRY_URL%';" ^
  "$key='HKCU:\Software\GUMS\EditIE';" ^
  "if (-not (Test-Path $pendingPath)) { exit 1 };" ^
  "$report = Get-Content $pendingPath -Raw | ConvertFrom-Json;" ^
  "$body = $report | ConvertTo-Json -Compress;" ^
  "Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 10 | Out-Null;" ^
  "Set-ItemProperty -Path $key -Name InstallReported -Value 1 -Type DWord;" ^
  "Remove-Item $pendingPath -Force" >nul 2>&1

exit /b

:TELEMETRY_SAVE_PENDING
mkdir C:\IEMode 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$key='HKCU:\Software\GUMS\EditIE';" ^
  "$pendingPath='%TELEMETRY_PENDING%';" ^
  "$id=(Get-ItemProperty -Path $key -Name InstallId -ErrorAction SilentlyContinue).InstallId;" ^
  "if (-not $id) { $id=[guid]::NewGuid().ToString(); Set-ItemProperty -Path $key -Name InstallId -Value $id };" ^
  "$report=[ordered]@{installId=$id;computerName=$env:COMPUTERNAME;windowsVersion=(Get-CimInstance Win32_OperatingSystem).Caption;version='%SCRIPT_VERSION%';installedAt=(Get-Date).ToUniversalTime().ToString('o')};" ^
  "$report | ConvertTo-Json | Set-Content -Path $pendingPath -Encoding UTF8" >nul 2>&1
exit /b