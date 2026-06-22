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

call :RUN_INTERNET_PS Apply

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

reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul

reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul

reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul

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

call :RUN_INTERNET_PS Reset

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

:RUN_INTERNET_PS
powershell -NoProfile -ExecutionPolicy Bypass -Command "$m='#POWERSHELL_SCRIPT#';$l=Get-Content -LiteralPath '%~f0' -Encoding UTF8;$s=[Array]::IndexOf($l,$m)+1;& ([scriptblock]::Create(($l[$s..($l.Length-1)] -join [Environment]::NewLine))) -Mode '%~1'"
exit /b %ERRORLEVEL%

goto :EOF

#POWERSHELL_SCRIPT#
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Apply', 'Reset')]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'

function Get-LoggedOnUserSid {
    $explorer = Get-WmiObject Win32_Process -Filter "Name='explorer.exe'" | Select-Object -First 1
    if ($explorer) {
        $owner = $explorer.GetOwner()
        return (New-Object System.Security.Principal.NTAccount($owner.Domain, $owner.User)).Translate(
            [System.Security.Principal.SecurityIdentifier]
        ).Value
    }

    return ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
}

function Get-UserRegRoot {
    $sid = Get-LoggedOnUserSid
    $root = "Registry::HKEY_USERS\$sid"
    if (-not (Test-Path $root)) {
        throw "Unable to access the logged-on user registry hive ($sid)."
    }
    return $root
}

function Get-UserKey {
    param([string]$RelativePath)

    $path = Join-Path (Get-UserRegRoot) $RelativePath
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    return $path
}

function Set-UserDword {
    param([string]$RelativePath, [string]$Name, [int]$Value)
    Set-ItemProperty -Path (Get-UserKey $RelativePath) -Name $Name -Value $Value -Type DWord
}

function Set-UserString {
    param([string]$RelativePath, [string]$Name, [string]$Value)
    Set-ItemProperty -Path (Get-UserKey $RelativePath) -Name $Name -Value $Value -Type String
}

function Remove-UserValue {
    param([string]$RelativePath, [string]$Name)
    $path = Join-Path (Get-UserRegRoot) $RelativePath
    if (Test-Path $path) {
        Remove-ItemProperty -Path $path -Name $Name -ErrorAction SilentlyContinue
    }
}

function Remove-UserTree {
    param([string]$RelativePath)
    $path = Join-Path (Get-UserRegRoot) $RelativePath
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
    }
}

function Set-LmPolicyDword {
    param([string]$RelativePath, [string]$Name, [int]$Value)
    $path = Join-Path 'HKLM:\SOFTWARE\Policies' $RelativePath
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    Set-ItemProperty -Path $path -Name $Name -Value $Value -Type DWord
}

function Set-LmPolicyString {
    param([string]$RelativePath, [string]$Name, [string]$Value)
    $path = Join-Path 'HKLM:\SOFTWARE\Policies' $RelativePath
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    Set-ItemProperty -Path $path -Name $Name -Value $Value -Type String
}

function Remove-LmPolicyValue {
    param([string]$RelativePath, [string]$Name)
    $path = Join-Path 'HKLM:\SOFTWARE\Policies' $RelativePath
    if (Test-Path $path) {
        Remove-ItemProperty -Path $path -Name $Name -ErrorAction SilentlyContinue
    }
}

function Set-SecuritySettings {
    param(
        [bool]$AllowInvalidSignatures,
        [bool]$DisableServerCertRevocation,
        [bool]$DisablePublisherCertRevocation,
        [bool]$DisableDownloadSignatureCheck,
        [bool]$AllowActiveContentFromCd,
        [bool]$AllowActiveContentInFiles,
        [bool]$DisableBlockUnsecureImages
    )

    $runInvalid = if ($AllowInvalidSignatures) { 1 } else { 0 }
    $serverCert = if ($DisableServerCertRevocation) { 0 } else { 1 }
    $publisherState = if ($DisablePublisherCertRevocation) { 146944 } else { 146432 }
    $checkExe = if ($DisableDownloadSignatureCheck) { 'no' } else { 'yes' }
    $cdUnlock = if ($AllowActiveContentFromCd) { 1 } else { 0 }
    $filesUnlock = if ($AllowActiveContentInFiles) { 0 } else { 1 }
    $filesUnlockIe11 = if ($AllowActiveContentInFiles) { 1 } else { 0 }
    $blockImages = if ($DisableBlockUnsecureImages) { 0 } else { 1 }

    $download = 'Software\Microsoft\Internet Explorer\Download'
    $main = 'Software\Microsoft\Internet Explorer\Main'
    $internetSettings = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $winTrust = 'Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing'
    $lm = 'Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN'
    $lmSettings = "$lm\Settings"

    Set-UserDword $download 'RunInvalidSignatures' $runInvalid
    Set-UserDword $download 'CertificateRevocation' $serverCert
    Set-UserDword $internetSettings 'CertificateRevocation' $serverCert
    Set-UserString $main 'CheckExeSignatures' $checkExe
    Set-UserString $download 'CheckExeSignatures' $checkExe
    Set-UserDword $winTrust 'State' $publisherState
    Set-UserDword $main 'MixedContentBlockImages' $blockImages
    Set-UserDword $main 'BlockUnsecureImages' $blockImages

    Set-UserDword $lm 'iexplore.exe' $filesUnlock
    Set-UserDword $lm 'LocalMachineFilesUnlock' $filesUnlockIe11
    Set-UserDword $lmSettings 'LOCALMACHINE_CD_UNLOCK' $cdUnlock
    Set-UserDword $lmSettings 'LocalMachine_CD_Unlock' $cdUnlock
    Set-UserDword $lmSettings 'LocalMachineCDUnlock' $cdUnlock

    Set-LmPolicyDword 'Microsoft\Internet Explorer\Download' 'RunInvalidSignatures' $runInvalid
    Set-LmPolicyDword 'Microsoft\Windows\CurrentVersion\Internet Settings' 'CertificateRevocation' $serverCert
    Set-LmPolicyString 'Microsoft\Internet Explorer\Main' 'CheckExeSignatures' $checkExe
    Set-LmPolicyDword 'Microsoft\Internet Explorer\Main' 'MixedContentBlockImages' $blockImages
    Set-LmPolicyDword 'Microsoft\Internet Explorer\Main' 'BlockUnsecureImages' $blockImages
    Set-LmPolicyDword 'Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN' 'iexplore.exe' $filesUnlock
    Set-LmPolicyDword 'Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN\Settings' 'LocalMachine_CD_Unlock' $cdUnlock
}

if ($Mode -eq 'Apply') {
    $ver = [Environment]::OSVersion.Version
    $secureProtocols = 2720
    if ($ver.Major -ge 10) {
        $secureProtocols = 10912
    }

    foreach ($sub in @('at', 'oa1', 'oa2', 'oa3', 'oa4')) {
        foreach ($proto in @('http', 'https')) {
            Set-UserDword "Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir\$sub" $proto 2
        }
    }

    Set-UserDword 'Software\Microsoft\Internet Explorer\New Windows' 'PopupMgr' 0
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'SecureProtocols' $secureProtocols
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'EnableNegotiate' 1
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'WarnonBadCertRecving' 1
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'DisableCachingOfSSLPages' 0
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'DoNotSaveEncrypted' 0
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'EnableInsecureTlsFallback' 1
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' 'EnableInsecureTlsFallback' 1
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\Cache' 'Persistent' 1
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\Cache' 'EmptyTemporary' 0
    Set-UserDword 'Software\Microsoft\Internet Explorer\Cache' 'Persistent' 1
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'XMLHTTP' 1
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'XmlHttp' 1
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'EnableDOMStorage' 1
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'AlwaysSendDoNotTrack' 0
    Set-UserString 'Software\Microsoft\Internet Explorer\Main' 'Delete_Temp_Files_On_Close' 'no'
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_DOMSTORAGE' 'iexplore.exe' 1

    Set-SecuritySettings `
        -AllowInvalidSignatures $true `
        -DisableServerCertRevocation $true `
        -DisablePublisherCertRevocation $true `
        -DisableDownloadSignatureCheck $true `
        -AllowActiveContentFromCd $true `
        -AllowActiveContentInFiles $true `
        -DisableBlockUnsecureImages $true

    $winHttpLm = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
    if (-not (Test-Path $winHttpLm)) {
        New-Item -Path $winHttpLm -Force | Out-Null
    }
    Set-ItemProperty -Path $winHttpLm -Name 'DefaultSecureProtocols' -Value $secureProtocols -Type DWord

    $winHttpWow = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
    if (Test-Path 'HKLM:\SOFTWARE\WOW6432Node') {
        if (-not (Test-Path $winHttpWow)) {
            New-Item -Path $winHttpWow -Force | Out-Null
        }
        Set-ItemProperty -Path $winHttpWow -Name 'DefaultSecureProtocols' -Value $secureProtocols -Type DWord
    }
}
else {
    Remove-UserTree 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir'
    Set-UserDword 'Software\Microsoft\Internet Explorer\New Windows' 'PopupMgr' 1
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'SecureProtocols' 2688
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'EnableNegotiate' 1
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'WarnonBadCertRecving' 1
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'DisableCachingOfSSLPages' 0
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'DoNotSaveEncrypted' 0
    Remove-UserValue 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'EnableInsecureTlsFallback'
    Remove-UserValue 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' 'EnableInsecureTlsFallback'
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\Cache' 'Persistent' 1
    Set-UserDword 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\Cache' 'EmptyTemporary' 0
    Set-UserDword 'Software\Microsoft\Internet Explorer\Cache' 'Persistent' 1
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'XMLHTTP' 1
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'XmlHttp' 1
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'EnableDOMStorage' 1
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'AlwaysSendDoNotTrack' 0
    Set-UserString 'Software\Microsoft\Internet Explorer\Main' 'Delete_Temp_Files_On_Close' 'no'
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_DOMSTORAGE' 'iexplore.exe' 1

    Set-SecuritySettings `
        -AllowInvalidSignatures $false `
        -DisableServerCertRevocation $false `
        -DisablePublisherCertRevocation $false `
        -DisableDownloadSignatureCheck $false `
        -AllowActiveContentFromCd $false `
        -AllowActiveContentInFiles $false `
        -DisableBlockUnsecureImages $false

    Remove-LmPolicyValue 'Microsoft\Internet Explorer\Download' 'RunInvalidSignatures'
    Remove-LmPolicyValue 'Microsoft\Windows\CurrentVersion\Internet Settings' 'CertificateRevocation'
    Remove-LmPolicyValue 'Microsoft\Internet Explorer\Main' 'CheckExeSignatures'
    Remove-LmPolicyValue 'Microsoft\Internet Explorer\Main' 'MixedContentBlockImages'
    Remove-LmPolicyValue 'Microsoft\Internet Explorer\Main' 'BlockUnsecureImages'
    Remove-LmPolicyValue 'Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN' 'iexplore.exe'
    Remove-LmPolicyValue 'Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN\Settings' 'LocalMachine_CD_Unlock'

    $winHttpLm = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
    if (Test-Path $winHttpLm) {
        Remove-ItemProperty -Path $winHttpLm -Name 'DefaultSecureProtocols' -ErrorAction SilentlyContinue
    }

    $winHttpWow = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
    if (Test-Path $winHttpWow) {
        Remove-ItemProperty -Path $winHttpWow -Name 'DefaultSecureProtocols' -ErrorAction SilentlyContinue
    }
}
