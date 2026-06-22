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
    param(
        [string]$RelativePath
    )

    $path = Join-Path (Get-UserRegRoot) $RelativePath
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    return $path
}

function Set-UserDword {
    param(
        [string]$RelativePath,
        [string]$Name,
        [int]$Value
    )

    Set-ItemProperty -Path (Get-UserKey $RelativePath) -Name $Name -Value $Value -Type DWord
}

function Set-UserString {
    param(
        [string]$RelativePath,
        [string]$Name,
        [string]$Value
    )

    Set-ItemProperty -Path (Get-UserKey $RelativePath) -Name $Name -Value $Value -Type String
}

function Remove-UserValue {
    param(
        [string]$RelativePath,
        [string]$Name
    )

    $path = Join-Path (Get-UserRegRoot) $RelativePath
    if (Test-Path $path) {
        Remove-ItemProperty -Path $path -Name $Name -ErrorAction SilentlyContinue
    }
}

function Remove-UserTree {
    param(
        [string]$RelativePath
    )

    $path = Join-Path (Get-UserRegRoot) $RelativePath
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
    }
}

function Set-LmPolicyDword {
    param(
        [string]$RelativePath,
        [string]$Name,
        [int]$Value
    )

    $path = Join-Path 'HKLM:\SOFTWARE\Policies' $RelativePath
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    Set-ItemProperty -Path $path -Name $Name -Value $Value -Type DWord
}

function Set-LmPolicyString {
    param(
        [string]$RelativePath,
        [string]$Name,
        [string]$Value
    )

    $path = Join-Path 'HKLM:\SOFTWARE\Policies' $RelativePath
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    Set-ItemProperty -Path $path -Name $Name -Value $Value -Type String
}

function Remove-LmPolicyValue {
    param(
        [string]$RelativePath,
        [string]$Name
    )

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
        [bool]$AllowActiveContentInFiles
    )

    $runInvalid = if ($AllowInvalidSignatures) { 1 } else { 0 }
    $serverCert = if ($DisableServerCertRevocation) { 0 } else { 1 }
    $publisherState = if ($DisablePublisherCertRevocation) { 146944 } else { 146432 }
    $checkExe = if ($DisableDownloadSignatureCheck) { 'no' } else { 'yes' }
    $cdUnlock = if ($AllowActiveContentFromCd) { 1 } else { 0 }
    $filesUnlock = if ($AllowActiveContentInFiles) { 0 } else { 1 }
    $filesUnlockIe11 = if ($AllowActiveContentInFiles) { 1 } else { 0 }

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

    Set-UserDword $lm 'iexplore.exe' $filesUnlock
    Set-UserDword $lm 'LocalMachineFilesUnlock' $filesUnlockIe11
    Set-UserDword $lmSettings 'LOCALMACHINE_CD_UNLOCK' $cdUnlock
    Set-UserDword $lmSettings 'LocalMachine_CD_Unlock' $cdUnlock
    Set-UserDword $lmSettings 'LocalMachineCDUnlock' $cdUnlock

    Set-LmPolicyDword 'Microsoft\Internet Explorer\Download' 'RunInvalidSignatures' $runInvalid
    Set-LmPolicyDword 'Microsoft\Windows\CurrentVersion\Internet Settings' 'CertificateRevocation' $serverCert
    Set-LmPolicyString 'Microsoft\Internet Explorer\Main' 'CheckExeSignatures' $checkExe
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
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'BlockUnsecureImages' 0
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'AlwaysSendDoNotTrack' 0
    Set-UserString 'Software\Microsoft\Internet Explorer\Main' 'Delete_Temp_Files_On_Close' 'no'
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_DOMSTORAGE' 'iexplore.exe' 1

    Set-SecuritySettings `
        -AllowInvalidSignatures $true `
        -DisableServerCertRevocation $true `
        -DisablePublisherCertRevocation $true `
        -DisableDownloadSignatureCheck $true `
        -AllowActiveContentFromCd $true `
        -AllowActiveContentInFiles $true

    $winProt = $secureProtocols
    $winHttpLm = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
    if (-not (Test-Path $winHttpLm)) {
        New-Item -Path $winHttpLm -Force | Out-Null
    }
    Set-ItemProperty -Path $winHttpLm -Name 'DefaultSecureProtocols' -Value $winProt -Type DWord

    $winHttpWow = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
    if (Test-Path 'HKLM:\SOFTWARE\WOW6432Node') {
        if (-not (Test-Path $winHttpWow)) {
            New-Item -Path $winHttpWow -Force | Out-Null
        }
        Set-ItemProperty -Path $winHttpWow -Name 'DefaultSecureProtocols' -Value $winProt -Type DWord
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
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'BlockUnsecureImages' 0
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main' 'AlwaysSendDoNotTrack' 0
    Set-UserString 'Software\Microsoft\Internet Explorer\Main' 'Delete_Temp_Files_On_Close' 'no'
    Set-UserDword 'Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_DOMSTORAGE' 'iexplore.exe' 1

    Set-SecuritySettings `
        -AllowInvalidSignatures $false `
        -DisableServerCertRevocation $false `
        -DisablePublisherCertRevocation $false `
        -DisableDownloadSignatureCheck $false `
        -AllowActiveContentFromCd $false `
        -AllowActiveContentInFiles $false

    Remove-LmPolicyValue 'Microsoft\Internet Explorer\Download' 'RunInvalidSignatures'
    Remove-LmPolicyValue 'Microsoft\Windows\CurrentVersion\Internet Settings' 'CertificateRevocation'
    Remove-LmPolicyValue 'Microsoft\Internet Explorer\Main' 'CheckExeSignatures'
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
