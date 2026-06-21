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
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ErrorActionPreference='Stop';" ^
"$explorer=Get-WmiObject Win32_Process -Filter \"Name='explorer.exe'\" ^| Select-Object -First 1;" ^
"if($explorer){$owner=$explorer.GetOwner();$sid=(New-Object System.Security.Principal.NTAccount($owner.Domain,$owner.User)).Translate([System.Security.Principal.SecurityIdentifier]).Value}else{$sid=([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value};" ^
"$root=\"Registry::HKEY_USERS\$sid\";" ^
"function Set-UReg([string]$rel,[string]$name,$value,[string]$type='DWord'){$p=Join-Path $root $rel;if(-not(Test-Path $p)){New-Item -Path $p -Force^|Out-Null};if($type -eq 'String'){Set-ItemProperty -Path $p -Name $name -Value $value -Type String}else{Set-ItemProperty -Path $p -Name $name -Value ([int]$value) -Type DWord}};" ^
"$zone='Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir';" ^
"foreach($sub in @('at','oa1','oa2','oa3','oa4')){foreach($proto in @('http','https')){Set-UReg (Join-Path $zone \"$sub\") $proto 2}};" ^
"Set-UReg 'Software\Microsoft\Internet Explorer\New Windows' 'PopupMgr' 0;" ^
"$is=Join-Path $root 'Software\Microsoft\Windows\CurrentVersion\Internet Settings';" ^
"if(-not(Test-Path $is)){New-Item -Path $is -Force^|Out-Null};" ^
"$ver=[Environment]::OSVersion.Version;" ^
"$secureProtocols=2720;if($ver.Major -ge 10){$secureProtocols=10912};" ^
"Set-ItemProperty -Path $is -Name 'SecureProtocols' -Value $secureProtocols -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'EnableNegotiate' -Value 1 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'CertificateRevocation' -Value 0 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'WarnonBadCertRecving' -Value 1 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'DisableCachingOfSSLPages' -Value 0 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'DoNotSaveEncrypted' -Value 0 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'EnableInsecureTlsFallback' -Value 1 -Type DWord;" ^
"$winhttp=Join-Path $is 'WinHttp';if(-not(Test-Path $winhttp)){New-Item -Path $winhttp -Force^|Out-Null};" ^
"Set-ItemProperty -Path $winhttp -Name 'EnableInsecureTlsFallback' -Value 1 -Type DWord;" ^
"$cache=Join-Path $is 'Cache';if(-not(Test-Path $cache)){New-Item -Path $cache -Force^|Out-Null};" ^
"Set-ItemProperty -Path $cache -Name 'Persistent' -Value 1 -Type DWord;" ^
"Set-ItemProperty -Path $cache -Name 'EmptyTemporary' -Value 0 -Type DWord;" ^
"$ieMain='Software\Microsoft\Internet Explorer\Main';" ^
"Set-UReg $ieMain 'XMLHTTP' 1;Set-UReg $ieMain 'XmlHttp' 1;" ^
"Set-UReg $ieMain 'EnableDOMStorage' 1;Set-UReg $ieMain 'BlockUnsecureImages' 0;" ^
"Set-UReg $ieMain 'AlwaysSendDoNotTrack' 0;" ^
"Set-UReg $ieMain 'Delete_Temp_Files_On_Close' 'no' 'String';" ^
"$lm='Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN';" ^
"Set-UReg $lm 'iexplore.exe' 0;Set-UReg $lm 'LocalMachineFilesUnlock' 1;" ^
"$lmSet=Join-Path $lm 'Settings';" ^
"Set-UReg $lmSet 'LOCALMACHINE_CD_UNLOCK' 1;Set-UReg $lmSet 'LocalMachineCDUnlock' 1;" ^
"$dom='Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_DOMSTORAGE';" ^
"Set-UReg $dom 'iexplore.exe' 1;" ^
"$dl='Software\Microsoft\Internet Explorer\Download';" ^
"Set-UReg $dl 'RunInvalidSignatures' 1;Set-UReg $dl 'CheckExeSignatures' 'no' 'String';" ^
"Set-UReg 'Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing' 'State' 146944;" ^
"$winProt=2720;if($ver.Major -ge 10){$winProt=10912};" ^
"$winHttpLm='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp';" ^
"if(-not(Test-Path $winHttpLm)){New-Item -Path $winHttpLm -Force^|Out-Null};" ^
"Set-ItemProperty -Path $winHttpLm -Name 'DefaultSecureProtocols' -Value $winProt -Type DWord;" ^
"$winHttpWow='HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp';" ^
"if(Test-Path 'HKLM:\SOFTWARE\WOW6432Node'){if(-not(Test-Path $winHttpWow)){New-Item -Path $winHttpWow -Force^|Out-Null};Set-ItemProperty -Path $winHttpWow -Name 'DefaultSecureProtocols' -Value $winProt -Type DWord};" ^
"if($LASTEXITCODE -ne 0){exit 1}"

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

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ErrorActionPreference='Stop';" ^
"$explorer=Get-WmiObject Win32_Process -Filter \"Name='explorer.exe'\" ^| Select-Object -First 1;" ^
"if($explorer){$owner=$explorer.GetOwner();$sid=(New-Object System.Security.Principal.NTAccount($owner.Domain,$owner.User)).Translate([System.Security.Principal.SecurityIdentifier]).Value}else{$sid=([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value};" ^
"$root=\"Registry::HKEY_USERS\$sid\";" ^
"function Set-UReg([string]$rel,[string]$name,$value,[string]$type='DWord'){$p=Join-Path $root $rel;if(-not(Test-Path $p)){New-Item -Path $p -Force^|Out-Null};if($type -eq 'String'){Set-ItemProperty -Path $p -Name $name -Value $value -Type String}else{Set-ItemProperty -Path $p -Name $name -Value ([int]$value) -Type DWord}};" ^
"function Remove-UKey([string]$rel){$p=Join-Path $root $rel;if(Test-Path $p){Remove-Item -Path $p -Recurse -Force}};" ^
"Remove-UKey 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir';" ^
"Set-UReg 'Software\Microsoft\Internet Explorer\New Windows' 'PopupMgr' 1;" ^
"$is=Join-Path $root 'Software\Microsoft\Windows\CurrentVersion\Internet Settings';" ^
"if(-not(Test-Path $is)){New-Item -Path $is -Force^|Out-Null};" ^
"Set-ItemProperty -Path $is -Name 'SecureProtocols' -Value 2688 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'EnableNegotiate' -Value 1 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'CertificateRevocation' -Value 1 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'WarnonBadCertRecving' -Value 1 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'DisableCachingOfSSLPages' -Value 0 -Type DWord;" ^
"Set-ItemProperty -Path $is -Name 'DoNotSaveEncrypted' -Value 0 -Type DWord;" ^
"if(Test-Path (Join-Path $is 'EnableInsecureTlsFallback')){Remove-ItemProperty -Path $is -Name 'EnableInsecureTlsFallback' -ErrorAction SilentlyContinue};" ^
"$winhttp=Join-Path $is 'WinHttp';if(Test-Path $winhttp){Remove-ItemProperty -Path $winhttp -Name 'EnableInsecureTlsFallback' -ErrorAction SilentlyContinue};" ^
"$cache=Join-Path $is 'Cache';if(-not(Test-Path $cache)){New-Item -Path $cache -Force^|Out-Null};" ^
"Set-ItemProperty -Path $cache -Name 'Persistent' -Value 1 -Type DWord;" ^
"Set-ItemProperty -Path $cache -Name 'EmptyTemporary' -Value 0 -Type DWord;" ^
"$ieMain='Software\Microsoft\Internet Explorer\Main';" ^
"Set-UReg $ieMain 'XMLHTTP' 1;Set-UReg $ieMain 'XmlHttp' 1;" ^
"Set-UReg $ieMain 'EnableDOMStorage' 1;Set-UReg $ieMain 'BlockUnsecureImages' 0;" ^
"Set-UReg $ieMain 'AlwaysSendDoNotTrack' 0;" ^
"Set-UReg $ieMain 'Delete_Temp_Files_On_Close' 'no' 'String';" ^
"$lm='Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN';" ^
"Set-UReg $lm 'iexplore.exe' 1;Set-UReg $lm 'LocalMachineFilesUnlock' 0;" ^
"$lmSet=Join-Path $lm 'Settings';" ^
"Set-UReg $lmSet 'LOCALMACHINE_CD_UNLOCK' 0;Set-UReg $lmSet 'LocalMachineCDUnlock' 0;" ^
"$dom='Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_DOMSTORAGE';" ^
"Set-UReg $dom 'iexplore.exe' 1;" ^
"$dl='Software\Microsoft\Internet Explorer\Download';" ^
"Set-UReg $dl 'RunInvalidSignatures' 0;Set-UReg $dl 'CheckExeSignatures' 'yes' 'String';" ^
"Set-UReg 'Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing' 'State' 146432;" ^
"if($LASTEXITCODE -ne 0){exit 1}"

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