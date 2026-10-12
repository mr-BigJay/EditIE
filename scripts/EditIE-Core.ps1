#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:EditIEDataRoot = 'C:\IEMode'
$script:EditIELogDir = Join-Path $script:EditIEDataRoot 'logs'
$script:EditIEBackupDir = Join-Path $script:EditIEDataRoot 'backup'
$script:EditIEContextFile = Join-Path $env:ProgramData 'GUMS-EditIE\launcher-context.json'

$script:PolicyInternetSettingsPaths = @(
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings'
    'HKCU:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings'
)

# WinInet / SecureProtocols client protocol bits (wininet/winsock2)
$script:SecureProtocolBits = @{
    Ssl3Client   = 0x00000020
    Tls10Client  = 0x00000080
    Tls11Client  = 0x00000200
    Tls12Client  = 0x00000800
    Tls13Client  = 0x00002000
}

$script:SchannelLegacyProtocols = @(
    'SSL 3.0'
    'TLS 1.0'
    'TLS 1.1'
)

function Get-EditIEScriptRoot {
    $root = Split-Path -Parent $PSScriptRoot
    if (-not (Test-Path (Join-Path $root 'scripts'))) {
        $root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    }
    return $root
}

function Initialize-EditIELogging {
    param([string]$OperationName)
    if (-not (Test-Path $script:EditIELogDir)) {
        New-Item -ItemType Directory -Path $script:EditIELogDir -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:LogFilePath = Join-Path $script:EditIELogDir "EditIE_${OperationName}_${stamp}.log"
    $script:LogEntries = New-Object System.Collections.Generic.List[object]
    Write-EditIELog "=== EditIE $OperationName started $(Get-Date -Format o) ==="
}

function Write-EditIELog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK', 'SKIP', 'BLOCKED')]
        [string]$Level = 'INFO'
    )
    $line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message"
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $line -Encoding UTF8
    }
    if ($null -ne $script:LogEntries) {
        $script:LogEntries.Add([pscustomobject]@{ Level = $Level; Message = $Message }) | Out-Null
    }
}

function Save-LaunchContext {
    if (-not (Test-Path (Split-Path $script:EditIEContextFile -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $script:EditIEContextFile -Parent) -Force | Out-Null
    }
    $ctx = Get-InteractiveUserContext -AllowUnresolved:$false
    $payload = @{
        capturedAt   = (Get-Date).ToString('o')
        userName     = $ctx.UserName
        userSid      = $ctx.UserSid
        sessionId    = $ctx.SessionId
        isSystem     = $ctx.IsSystem
        processUser  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
    $payload | ConvertTo-Json -Depth 4 | Set-Content -Path $script:EditIEContextFile -Encoding UTF8
}

function Get-LaunchContext {
    if (-not (Test-Path $script:EditIEContextFile)) {
        return $null
    }
    try {
        return Get-Content -Path $script:EditIEContextFile -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-InteractiveUserContext {
    param([switch]$AllowUnresolved)

    $current = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $isSystem = $current.IsSystem

    $userName = $null
    $sessionId = $null

    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($cs.UserName) {
            $userName = $cs.UserName
        }
    }
    catch {
        Write-Verbose $_.Exception.Message
    }

    if (-not $userName) {
        try {
            $q = query user 2>$null | Select-Object -Skip 1
            foreach ($row in $q) {
                if ($row -match '^\s*>?\s*(\S+)\s+(\d+)\s+') {
                    $userName = $matches[1]
                    $sessionId = [int]$matches[2]
                    break
                }
            }
        }
        catch { }
    }

    if (-not $userName -and -not $isSystem) {
        $userName = $current.Name
    }

    $sid = $null
    if ($userName) {
        try {
            if ($userName -notmatch '\\') {
                $userName = "$env:USERDOMAIN\$userName"
            }
            $nt = New-Object System.Security.Principal.NTAccount($userName)
            $sid = $nt.Translate([System.Security.Principal.SecurityIdentifier]).Value
        }
        catch {
            Write-Verbose $_.Exception.Message
        }
    }

    if (-not $sid -and -not $isSystem) {
        $sid = $current.User.Value
        if (-not $userName) { $userName = $current.Name }
    }

    if (-not $sid -and $AllowUnresolved) {
        return [pscustomobject]@{
            UserName   = $userName
            UserSid    = $null
            SessionId  = $sessionId
            IsSystem   = $isSystem
            Resolved   = $false
        }
    }

    if (-not $sid) {
        throw "Could not resolve the interactive user (common when running as SYSTEM without a logged-on user). Run the tool from the target user's session or use a deployment method that supplies the user profile."
    }

    return [pscustomobject]@{
        UserName   = $userName
        UserSid    = $sid
        SessionId  = $sessionId
        IsSystem   = $isSystem
        Resolved   = $true
    }
}

function Get-TargetUserContext {
    $saved = Get-LaunchContext
    if ($saved -and $saved.userSid) {
        return [pscustomobject]@{
            UserName  = [string]$saved.userName
            UserSid   = [string]$saved.userSid
            IsSystem  = [bool]$saved.isSystem
            Source    = 'LaunchContext'
            Resolved  = $true
        }
    }
    return Get-InteractiveUserContext
}

function Test-UserHiveLoaded {
    param([string]$UserSid)
    return Test-Path "Registry::HKEY_USERS\$UserSid\Software"
}

function Get-UserRegistryMount {
    param([string]$UserSid)

    if (Test-UserHiveLoaded -UserSid $UserSid) {
        return [pscustomobject]@{
            HivePrefix = "HKU:\$UserSid"
            RegPrefix  = "HKU\$UserSid"
            Loaded     = $true
            TempLoad   = $false
        }
    }
    throw "The registry hive for user SID $UserSid is not loaded. Log on as that user (or keep the session active) and run the tool again."
}

function ConvertTo-RegExePath {
    param(
        [string]$HivePrefix,
        [string]$SubKey
    )
    if ($HivePrefix -like 'HKU:*') {
        $sid = ($HivePrefix -replace '^HKU:\\', '')
        return "HKU\$sid\$SubKey"
    }
    if ($HivePrefix -like 'HKLM:*') {
        return "HKLM\$SubKey"
    }
    if ($HivePrefix -like 'HKCU:*') {
        return "HKCU\$SubKey"
    }
    return "$HivePrefix\$SubKey"
}

function Get-RegistryValue {
    param(
        [string]$HivePrefix,
        [string]$SubKey,
        [string]$Name
    )
    $regPath = ConvertTo-RegExePath -HivePrefix $HivePrefix -SubKey $SubKey
    $output = & reg.exe query $regPath /v $Name 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    $line = ($output | Where-Object { $_ -match 'REG_' }) | Select-Object -First 1
    if (-not $line) { return $null }
    if ($line -match 'REG_DWORD\s+0x([0-9a-fA-F]+)') {
        return [convert]::ToInt32($matches[1], 16)
    }
    if ($line -match 'REG_DWORD\s+(\d+)') {
        return [int]$matches[1]
    }
    if ($line -match 'REG_SZ\s+(.*)$') {
        return $matches[1].Trim()
    }
    return $null
}

function Test-RegistryKeyExists {
    param(
        [string]$HivePrefix,
        [string]$SubKey
    )
    $regPath = ConvertTo-RegExePath -HivePrefix $HivePrefix -SubKey $SubKey
    & reg.exe query $regPath 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Invoke-EditIERegistry {
    param(
        [ValidateSet('Add', 'Delete')]
        [string]$Operation,
        [string]$HivePrefix,
        [string]$SubKey,
        [string]$Name,
        [string]$Type = 'REG_DWORD',
        [string]$Data,
        [string]$SettingLabel
    )

    $regPath = ConvertTo-RegExePath -HivePrefix $HivePrefix -SubKey $SubKey
    $label = if ($SettingLabel) { $SettingLabel } else { "$regPath\$Name" }

    if ($Operation -eq 'Add') {
        $output = & reg.exe add $regPath /v $Name /t $Type /d $Data /f 2>&1
    }
    else {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            $output = & reg.exe delete $regPath /f 2>&1
        }
        else {
            $output = & reg.exe delete $regPath /v $Name /f 2>&1
        }
    }

    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        $msg = ($output | Out-String).Trim()
        Write-EditIELog "$label -> Failed ($msg)" 'ERROR'
        return [pscustomobject]@{
            Label  = $label
            Status = 'Failed'
            Detail = $msg
        }
    }

    if ($Operation -eq 'Add') {
        $expected = if ($Type -eq 'REG_DWORD') { [int]$Data } else { $Data }
        $actual = Get-RegistryValue -HivePrefix $HivePrefix -SubKey $SubKey -Name $Name
        $ok = ($null -ne $actual)
        if ($ok -and $Type -eq 'REG_DWORD') {
            $ok = ([int]$actual -eq [int]$expected)
        }
        elseif ($ok -and $Type -eq 'REG_SZ') {
            $ok = ("$actual" -eq "$expected")
        }
        if (-not $ok) {
            Write-EditIELog "$label -> Failed verification (expected $expected, got $actual)" 'ERROR'
            return [pscustomobject]@{
                Label  = $label
                Status = 'Failed'
                Detail = "Verification failed (expected $expected, got $actual)"
            }
        }
    }
    else {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            if (Test-RegistryKeyExists -HivePrefix $HivePrefix -SubKey $SubKey) {
                Write-EditIELog "$label -> Failed verification (key still present)" 'ERROR'
                return [pscustomobject]@{
                    Label  = $label
                    Status = 'Failed'
                    Detail = 'Key still present after delete'
                }
            }
        }
        else {
            $remaining = Get-RegistryValue -HivePrefix $HivePrefix -SubKey $SubKey -Name $Name
            if ($null -ne $remaining) {
                Write-EditIELog "$label -> Failed verification (value still present)" 'ERROR'
                return [pscustomobject]@{
                    Label  = $label
                    Status = 'Failed'
                    Detail = 'Value still present after delete'
                }
            }
        }
    }

    Write-EditIELog "$label -> Success" 'OK'
    return [pscustomobject]@{
        Label  = $label
        Status = 'Success'
        Detail = ''
    }
}

function Get-SecureProtocolsPolicyBlock {
    $blocks = @()
    foreach ($path in $script:PolicyInternetSettingsPaths) {
        if (-not (Test-Path $path)) { continue }
        $prop = Get-ItemProperty -Path $path -Name SecureProtocols -ErrorAction SilentlyContinue
        if ($null -ne $prop -and $null -ne $prop.SecureProtocols) {
            $blocks += [pscustomobject]@{
                Path  = $path
                Value = [int]$prop.SecureProtocols
            }
        }
    }
    return $blocks
}

function Get-AdvancedCryptoOptions {
    $root = 'HKLM:\Software\Microsoft\Internet Explorer\AdvancedOptions\CRYPTO'
    $options = @()
    if (-not (Test-Path $root)) {
        return $options
    }
    Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $key = $_
        $checked = Get-ItemProperty -Path $key.PSPath -Name 'CheckedValue' -ErrorAction SilentlyContinue
        $text = Get-ItemProperty -Path $key.PSPath -Name 'Text' -ErrorAction SilentlyContinue
        if ($null -ne $checked -and $null -ne $checked.CheckedValue) {
            $options += [pscustomobject]@{
                Name         = $key.PSChildName
                Text         = [string]$text.Text
                CheckedValue = [int]$checked.CheckedValue
                KeyPath      = $key.PSPath
            }
        }
    }
    return $options
}

function Test-Tls13RuntimeSupport {
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 19041) { return $false }

    $clientKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client'
    if (-not (Test-Path $clientKey)) { return $false }

    $disabled = Get-ItemProperty -Path $clientKey -Name 'DisabledByDefault' -ErrorAction SilentlyContinue
    $enabled = Get-ItemProperty -Path $clientKey -Name 'Enabled' -ErrorAction SilentlyContinue
    if ($null -ne $disabled -and [int]$disabled.DisabledByDefault -eq 1) {
        if ($null -eq $enabled -or [int]$enabled.Enabled -ne 1) {
            # OS may still ship the key but default-disabled; UI may expose TLS 1.3 on Win11+
            if ($build -ge 22000) { return $true }
            return $false
        }
    }
    return $true
}

function Add-CryptoProtocolBits {
    param(
        [object[]]$CryptoOptions,
        [string[]]$Patterns,
        [int]$FallbackBit,
        [string]$Label,
        [ref]$MaskRef,
        [System.Collections.Generic.List[string]]$IncludedRef
    )
    $local = 0
    $matched = $false
    foreach ($opt in $CryptoOptions) {
        $blob = ($opt.Name + ' ' + $opt.Text).ToLowerInvariant()
        foreach ($p in $Patterns) {
            if ($blob -match $p) {
                $local = $local -bor [int]$opt.CheckedValue
                $matched = $true
            }
        }
    }
    if (-not $matched) {
        $local = $FallbackBit
    }
    if ($local -ne 0) {
        $MaskRef.Value = $MaskRef.Value -bor $local
        $IncludedRef.Add($Label) | Out-Null
    }
}

function Get-SecureProtocolsMask {
    param(
        [switch]$LegacyTls
    )

    $crypto = Get-AdvancedCryptoOptions
    $included = New-Object System.Collections.Generic.List[string]
    $maskAcc = 0

    Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('tls 1.2', 'tls1.2') -FallbackBit $script:SecureProtocolBits.Tls12Client -Label 'TLS 1.2' -MaskRef ([ref]$maskAcc) -IncludedRef $included
    if (Test-Tls13RuntimeSupport) {
        Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('tls 1.3', 'tls1.3') -FallbackBit $script:SecureProtocolBits.Tls13Client -Label 'TLS 1.3' -MaskRef ([ref]$maskAcc) -IncludedRef $included
    }
    else {
        Write-EditIELog 'TLS 1.3 not enabled (OS/Schannel support not confirmed)' 'SKIP'
    }

    if ($LegacyTls) {
        Write-EditIELog 'Legacy TLS mode selected — weak protocols will be enabled for compatibility' 'WARN'
        Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('ssl 3.0', 'ssl3') -FallbackBit $script:SecureProtocolBits.Ssl3Client -Label 'SSL 3.0 (legacy)' -MaskRef ([ref]$maskAcc) -IncludedRef $included
        Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('tls 1.0', 'tls1.0') -FallbackBit $script:SecureProtocolBits.Tls10Client -Label 'TLS 1.0 (legacy)' -MaskRef ([ref]$maskAcc) -IncludedRef $included
        Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('tls 1.1', 'tls1.1') -FallbackBit $script:SecureProtocolBits.Tls11Client -Label 'TLS 1.1 (legacy)' -MaskRef ([ref]$maskAcc) -IncludedRef $included
    }

    $mask = $maskAcc -band 0x0000FFFF

    return [pscustomobject]@{
        Value     = $mask
        Hex       = ('0x{0:X}' -f $mask)
        Protocols = [string[]]$included
    }
}

function Set-SchannelLegacyClientProtocols {
    param([switch]$Enable)

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($proto in $script:SchannelLegacyProtocols) {
        $sub = "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$proto\Client"
        if ($Enable) {
            $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey $sub -Name 'Enabled' -Data '1' -SettingLabel "Schannel $proto Client Enabled")) | Out-Null
            $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey $sub -Name 'DisabledByDefault' -Data '0' -SettingLabel "Schannel $proto Client DisabledByDefault")) | Out-Null
        }
    }
    return $results
}

function Get-BackupFilePath {
    param([string]$UserSid)
    Join-Path $script:EditIEBackupDir "backup_$UserSid.json"
}

function Export-RegistrySnapshotEntry {
    param(
        [string]$HivePrefix,
        [string]$SubKey,
        [string]$Name,
        [string]$Type = 'REG_DWORD'
    )
    $exists = Test-RegistryKeyExists -HivePrefix $HivePrefix -SubKey $SubKey
    $value = $null
    $hadValue = $false
    if ($exists) {
        $value = Get-RegistryValue -HivePrefix $HivePrefix -SubKey $SubKey -Name $Name
        $hadValue = ($null -ne $value)
    }
    return [pscustomobject]@{
        hivePrefix = $HivePrefix
        subKey     = $SubKey
        name       = $Name
        type       = $Type
        value      = $value
        existed    = $hadValue
        keyExisted = $exists
    }
}

function Initialize-SettingsBackup {
    param(
        [string]$UserSid,
        [string]$UserHivePrefix
    )

    if (-not (Test-Path $script:EditIEBackupDir)) {
        New-Item -ItemType Directory -Path $script:EditIEBackupDir -Force | Out-Null
    }

    $backupPath = Get-BackupFilePath -UserSid $UserSid
    if (Test-Path $backupPath) {
        Write-EditIELog "Backup already exists: $backupPath" 'INFO'
        return Get-Content $backupPath -Raw | ConvertFrom-Json
    }

    Write-EditIELog "Creating backup for SID $UserSid" 'INFO'

    $entries = @()

    $trustedBase = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir'
    $entries += [pscustomobject]@{
        hivePrefix = $UserHivePrefix
        subKey     = $trustedBase
        name       = '__KEY__'
        type       = 'REG_KEY'
        value      = $null
        existed    = (Test-RegistryKeyExists -HivePrefix $UserHivePrefix -SubKey $trustedBase)
        keyExisted = (Test-RegistryKeyExists -HivePrefix $UserHivePrefix -SubKey $trustedBase)
    }
    foreach ($sub in @('at', 'oa1', 'oa2', 'oa3', 'oa4')) {
        foreach ($proto in @('http', 'https')) {
            $entries += Export-RegistrySnapshotEntry -HivePrefix $UserHivePrefix -SubKey "$trustedBase\$sub" -Name $proto
        }
    }

    $entries += Export-RegistrySnapshotEntry -HivePrefix $UserHivePrefix -SubKey 'Software\Microsoft\Internet Explorer\New Windows' -Name 'PopupMgr'
    $entries += Export-RegistrySnapshotEntry -HivePrefix $UserHivePrefix -SubKey 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name 'SecureProtocols'
    $entries += Export-RegistrySnapshotEntry -HivePrefix $UserHivePrefix -SubKey 'Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing' -Name 'State'

    foreach ($path in @(
            'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
            'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
        )) {
        $entries += Export-RegistrySnapshotEntry -HivePrefix 'HKLM:' -SubKey $path -Name 'DefaultSecureProtocols'
    }

    $entries += Export-RegistrySnapshotEntry -HivePrefix 'HKLM:' -SubKey 'SOFTWARE\Policies\Microsoft\Edge' -Name 'InternetExplorerIntegrationLevel'
    $entries += Export-RegistrySnapshotEntry -HivePrefix 'HKLM:' -SubKey 'SOFTWARE\Policies\Microsoft\Edge' -Name 'InternetExplorerIntegrationSiteList'

    foreach ($proto in @('SSL 3.0', 'TLS 1.0', 'TLS 1.1', 'TLS 1.2', 'TLS 1.3')) {
        $base = "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$proto\Client"
        foreach ($n in @('Enabled', 'DisabledByDefault')) {
            $entries += Export-RegistrySnapshotEntry -HivePrefix 'HKLM:' -SubKey $base -Name $n
        }
    }

    $payload = @{
        version   = 2
        createdAt = (Get-Date).ToString('o')
        userSid   = $UserSid
        entries   = @($entries | ForEach-Object {
                @{
                    hivePrefix = $_.hivePrefix
                    subKey     = $_.subKey
                    name       = $_.name
                    type       = $_.type
                    value      = $_.value
                    existed    = $_.existed
                    keyExisted = $_.keyExisted
                }
            })
    }

    $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $backupPath -Encoding UTF8
    Write-EditIELog "Backup saved to $backupPath" 'OK'
    return $payload
}

function Restore-SettingsFromBackup {
    param(
        [string]$UserSid,
        [string]$UserHivePrefix
    )

    $backupPath = Get-BackupFilePath -UserSid $UserSid
    if (-not (Test-Path $backupPath)) {
        throw "No backup file found at $backupPath. Cannot restore safely."
    }

    $backup = Get-Content $backupPath -Raw | ConvertFrom-Json
    $results = New-Object System.Collections.Generic.List[object]

    foreach ($entry in $backup.entries) {
        $hive = [string]$entry.hivePrefix
        if ($hive -like 'HKU:*' -or $hive -eq 'HKCU:') {
            $hive = $UserHivePrefix
        }

        $sub = [string]$entry.subKey
        $name = [string]$entry.name
        if ($name -eq '__KEY__' -and $entry.type -eq 'REG_KEY') {
            if (-not [bool]$entry.keyExisted) {
                if (Test-RegistryKeyExists -HivePrefix $hive -SubKey $sub) {
                    $results.Add((Invoke-EditIERegistry -Operation Delete -HivePrefix $hive -SubKey $sub -Name '' -SettingLabel "Remove key $sub")) | Out-Null
                }
                else {
                    Write-EditIELog "Key $sub already absent — skipped" 'SKIP'
                    $results.Add([pscustomobject]@{ Label = "Key $sub"; Status = 'Skipped'; Detail = 'Already absent' }) | Out-Null
                }
            }
            else {
                Write-EditIELog "Key $sub existed before backup — not removing tree" 'SKIP'
            }
            continue
        }

        if (-not [bool]$entry.existed) {
            $cur = Get-RegistryValue -HivePrefix $hive -SubKey $sub -Name $name
            if ($null -ne $cur) {
                $results.Add((Invoke-EditIERegistry -Operation Delete -HivePrefix $hive -SubKey $sub -Name $name -SettingLabel "Restore delete $sub\$name")) | Out-Null
            }
            else {
                Write-EditIELog "$sub\$name was not in backup — skipped" 'SKIP'
                $results.Add([pscustomobject]@{ Label = "$sub\$name"; Status = 'Skipped'; Detail = 'Not present before backup' }) | Out-Null
            }
        }
        else {
            $type = if ($entry.type) { [string]$entry.type } else { 'REG_DWORD' }
            $val = $entry.value
            $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix $hive -SubKey $sub -Name $name -Type $type -Data "$val" -SettingLabel "Restore $sub\$name")) | Out-Null
        }
    }

    return $results
}

function Show-EditIESummary {
    param(
        [object[]]$Results,
        [string[]]$Notes = @()
    )

    $groups = $Results | Group-Object Status
    Write-Host ''
    Write-Host '----------------------------------------------------------'
    Write-Host ' Summary'
    Write-Host '----------------------------------------------------------'
    foreach ($g in $groups) {
        Write-Host (" {0}: {1}" -f $g.Name, $g.Count)
    }
    foreach ($n in $Notes) {
        Write-Host " Note: $n"
    }
    if ($script:LogFilePath) {
        Write-Host " Log: $script:LogFilePath"
    }
    Write-Host '----------------------------------------------------------'
}

function Test-AllRequiredSuccess {
    param(
        [object[]]$Results,
        [string[]]$RequiredLabels
    )
    foreach ($label in $RequiredLabels) {
        $r = $Results | Where-Object { $_.Label -like "*$label*" } | Select-Object -Last 1
        if (-not $r -or $r.Status -ne 'Success') {
            return $false
        }
    }
    return $true
}
