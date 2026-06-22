@echo off

set SCRIPT_VERSION=1.0.0
set TELEMETRY_URL=http://185.252.200.112:8080/api/install
set TELEMETRY_HEALTH=http://185.252.200.112:8080/health
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
echo   If the server is not reachable, the report stays on this PC
echo   and is sent automatically when OpenVPN connects or any
echo   new network becomes available.
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
    call :TELEMETRY_REGISTER_TASK
) else (
    reg add "HKCU\Software\GUMS\EditIE" /v TelemetryOptIn /t REG_DWORD /d 0 /f >nul
)

:TELEMETRY_MAYBE_SEND
reg query "HKCU\Software\GUMS\EditIE" /v TelemetryOptIn | find "0x1" >nul
if %ERRORLEVEL% NEQ 0 exit /b

reg query "HKCU\Software\GUMS\EditIE" /v InstallReported >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    schtasks /Delete /TN "GUMS-EditIE-Telemetry" /F >nul 2>&1
    exit /b
)

if not exist "C:\IEMode\telemetry_pending.json" call :TELEMETRY_SAVE_PENDING

call :TELEMETRY_REGISTER_TASK
call :TELEMETRY_TRY_SEND

exit /b

:TELEMETRY_TRY_SEND
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\IEMode\send-telemetry.ps1" >nul 2>&1
exit /b

:TELEMETRY_REGISTER_TASK
mkdir C:\IEMode 2>nul
call :TELEMETRY_WRITE_SCRIPT
call :TELEMETRY_WRITE_TASK_XML
call :TELEMETRY_WRITE_VPN_HOOK
powershell -NoProfile -Command "Get-Content 'C:\IEMode\telemetry-task.xml' -Raw | Out-File 'C:\IEMode\telemetry-task.xml' -Encoding Unicode" >nul 2>&1
schtasks /Create /TN "GUMS-EditIE-Telemetry" /XML "C:\IEMode\telemetry-task.xml" /F >nul 2>&1
exit /b

:TELEMETRY_WRITE_TASK_XML
(
echo ^<?xml version="1.0" encoding="UTF-16"?^>
echo ^<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo   ^<RegistrationInfo^>^<Description^>Send GUMS EditIE report when VPN/network connects^</Description^>^</RegistrationInfo^>
echo   ^<Triggers^>
echo     ^<EventTrigger^>^<Enabled^>true^</Enabled^>^<Subscription^>^&lt;QueryList^>^&lt;Query Id="0"^>^&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"^>^*[System[EventID=10000]]^&lt;/Select^>^&lt;/Query^>^&lt;/QueryList^>^</Subscription^>^</EventTrigger^>
echo     ^<EventTrigger^>^<Enabled^>true^</Enabled^>^<Subscription^>^&lt;QueryList^>^&lt;Query Id="0"^>^&lt;Select Path="Microsoft-Windows-Ras-Client/Operational"^>^*[System[EventID=20225]]^&lt;/Select^>^&lt;/Query^>^&lt;/QueryList^>^</Subscription^>^</EventTrigger^>
echo     ^<LogonTrigger^>^<Enabled^>true^</Enabled^>^</LogonTrigger^>
echo   ^</Triggers^>
echo   ^<Principals^>^<Principal id="Author"^>^<LogonType^>InteractiveToken^</LogonType^>^<RunLevel^>LeastPrivilege^</RunLevel^>^</Principal^>^</Principals^>
echo   ^<Settings^>^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>^<StartWhenAvailable^>true^</StartWhenAvailable^>^<AllowStartOnDemand^>true^</AllowStartOnDemand^>^<Hidden^>true^</Hidden^>^<ExecutionTimeLimit^>PT2M^</ExecutionTimeLimit^>^</Settings^>
echo   ^<Actions Context="Author"^>^<Exec^>^<Command^>powershell.exe^</Command^>^<Arguments^>-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\IEMode\send-telemetry.ps1^</Arguments^>^</Exec^>^</Actions^>
echo ^</Task^>
) > "C:\IEMode\telemetry-task.xml"
exit /b

:TELEMETRY_WRITE_SCRIPT
(
echo $key = 'HKCU:\Software\GUMS\EditIE'
echo $pendingPath = 'C:\IEMode\telemetry_pending.json'
echo $url = '%TELEMETRY_URL%'
echo $healthUrl = '%TELEMETRY_HEALTH%'
echo $taskName = 'GUMS-EditIE-Telemetry'
echo.
echo if ^((Get-ItemProperty -Path $key -Name InstallReported -ErrorAction SilentlyContinue^).InstallReported -eq 1^) {
echo     Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
echo     exit 0
echo }
echo.
echo if ^(-not ^(Test-Path $pendingPath^)^) { exit 0 }
echo.
echo try {
echo     Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 5 ^| Out-Null
echo } catch {
echo     exit 0
echo }
echo.
echo try {
echo     $report = Get-Content $pendingPath -Raw ^| ConvertFrom-Json
echo     $body = $report ^| ConvertTo-Json -Compress
echo     Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 10 ^| Out-Null
echo     Set-ItemProperty -Path $key -Name InstallReported -Value 1 -Type DWord
echo     Remove-Item $pendingPath -Force
echo     Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
echo } catch {
echo     exit 1
echo }
) > "C:\IEMode\send-telemetry.ps1"
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