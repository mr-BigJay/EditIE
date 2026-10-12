#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'EditIE-Logic.ps1')

$script:SecureProtocolBits = @{
    Ssl3Client  = 0x00000020
    Tls10Client = 0x00000080
    Tls11Client = 0x00000200
    Tls12Client = 0x00000800
    Tls13Client = 0x00002000
}

$script:EditIEDataRoot = 'C:\IEMode'
$script:EditIELogDir = Join-Path $script:EditIEDataRoot 'logs'
$script:EditIEBackupDir = Join-Path $script:EditIEDataRoot 'backup'
$script:EditIEContextDir = Join-Path $env:ProgramData 'GUMS-EditIE\contexts'
$script:EditIESitesXml = Join-Path $script:EditIEDataRoot 'sites.xml'
$script:EditIEMachineBackup = Join-Path $script:EditIEBackupDir 'backup_machine.json'

$script:SchannelLegacyProtocols = @('SSL 3.0', 'TLS 1.0', 'TLS 1.1')

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
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK', 'SKIP', 'BLOCKED', 'UNSUPPORTED')]
        [string]$Level = 'INFO'
    )
    $line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message"
    if ($script:LogFilePath) { Add-Content -Path $script:LogFilePath -Value $line -Encoding UTF8 }
    if ($null -ne $script:LogEntries) {
        $script:LogEntries.Add([pscustomobject]@{ Level = $Level; Message = $Message }) | Out-Null
    }
}

function Get-OsBuildInfo {
    $ver = [System.Environment]::OSVersion.Version
    $build = $ver.Build
    try {
        $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        if ($cv.CurrentBuildNumber) { $build = [int]$cv.CurrentBuildNumber }
    }
    catch { }
    $isWin11 = ($build -ge 22000)
    return [pscustomobject]@{ Build = $build; IsWindows11OrLater = $isWin11 }
}

function Invoke-RegExe {
    param([string[]]$Arguments)
    $output = & reg.exe @Arguments 2>&1
    $exit = $LASTEXITCODE
    $text = ($output | Out-String).Trim()
    return [pscustomobject]@{ ExitCode = $exit; Output = $text; Lines = @($output) }
}

function Invoke-RegQueryValue {
    param(
        [string]$HivePrefix,
        [string]$SubKey,
        [string]$Name
    )
    $regPath = ConvertTo-RegExePath -HivePrefix $HivePrefix -SubKey $SubKey
    $r = Invoke-RegExe -Arguments @('query', $regPath, '/v', $Name)
    if ($r.ExitCode -eq 0) {
        $line = $r.Lines | Where-Object { $_ -match 'REG_' } | Select-Object -First 1
        if (-not $line) {
            return [pscustomobject]@{ Status = 'Error'; Value = $null; Message = 'Unexpected reg query output' }
        }
        if ($line -match 'REG_DWORD\s+0x([0-9a-fA-F]+)') {
            return [pscustomobject]@{ Status = 'Found'; Value = [convert]::ToInt32($matches[1], 16); Message = '' }
        }
        if ($line -match 'REG_DWORD\s+(\d+)') {
            return [pscustomobject]@{ Status = 'Found'; Value = [int]$matches[1]; Message = '' }
        }
        if ($line -match 'REG_SZ\s+(.*)$') {
            return [pscustomobject]@{ Status = 'Found'; Value = $matches[1].Trim(); Message = '' }
        }
        return [pscustomobject]@{ Status = 'Error'; Value = $null; Message = "Unparsed: $line" }
    }
    if ($r.Output -match '(?i)access is denied|access denied') {
        return [pscustomobject]@{ Status = 'AccessDenied'; Value = $null; Message = $r.Output }
    }
    if ($r.Output -match '(?i)error.*(cannot find|unable to find|not found)') {
        return [pscustomobject]@{ Status = 'NotFound'; Value = $null; Message = $r.Output }
    }
    return [pscustomobject]@{ Status = 'Error'; Value = $null; Message = $r.Output }
}

function Invoke-RegTestKey {
    param(
        [string]$HivePrefix,
        [string]$SubKey
    )
    $regPath = ConvertTo-RegExePath -HivePrefix $HivePrefix -SubKey $SubKey
    $r = Invoke-RegExe -Arguments @('query', $regPath)
    if ($r.ExitCode -eq 0) { return [pscustomobject]@{ Status = 'Found'; Message = '' } }
    if ($r.Output -match '(?i)access is denied|access denied') {
        return [pscustomobject]@{ Status = 'AccessDenied'; Message = $r.Output }
    }
    return [pscustomobject]@{ Status = 'NotFound'; Message = $r.Output }
}

function Get-RegistryValue {
    param([string]$HivePrefix, [string]$SubKey, [string]$Name)
    $q = Invoke-RegQueryValue -HivePrefix $HivePrefix -SubKey $SubKey -Name $Name
    if ($q.Status -eq 'Found') { return $q.Value }
    return $null
}

function Test-RegistryKeyExists {
    param([string]$HivePrefix, [string]$SubKey)
    return (Invoke-RegTestKey -HivePrefix $HivePrefix -SubKey $SubKey).Status -eq 'Found'
}

function Get-InteractiveUserContext {
    param([switch]$AllowUnresolved)

    $current = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $isSystem = $current.IsSystem
    if ($isSystem -and -not $AllowUnresolved) {
        throw 'Running as SYSTEM without a validated launch context. Run from the target user session (fail-safe).'
    }

    $userName = $null
    $sessionId = $null
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($cs.UserName) { $userName = $cs.UserName }
    }
    catch { }

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

    if (-not $userName -and -not $isSystem) { $userName = $current.Name }

    $sid = $null
    if ($userName) {
        try {
            if ($userName -notmatch '\\') { $userName = "$env:USERDOMAIN\$userName" }
            $nt = New-Object System.Security.Principal.NTAccount($userName)
            $sid = $nt.Translate([System.Security.Principal.SecurityIdentifier]).Value
        }
        catch { }
    }
    if (-not $sid -and -not $isSystem) {
        $sid = $current.User.Value
        if (-not $userName) { $userName = $current.Name }
    }

    if (-not $sid -and $AllowUnresolved) {
        return [pscustomobject]@{ UserName = $userName; UserSid = $null; SessionId = $sessionId; IsSystem = $isSystem; Resolved = $false }
    }
    if (-not $sid) {
        throw 'Could not resolve the interactive user. Run from the target user session.'
    }
    return [pscustomobject]@{ UserName = $userName; UserSid = $sid; SessionId = $sessionId; IsSystem = $isSystem; Resolved = $true }
}

function Set-ContextFileAcl {
    param([string]$FilePath)
    try {
        $acl = Get-Acl -Path $FilePath
        $acl.SetAccessRuleProtection($true, $false)
        $adminSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
        $systemSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
        $ruleAdmin = New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid, 'Read', 'Allow')
        $ruleSystem = New-Object System.Security.AccessControl.FileSystemAccessRule($systemSid, 'Read', 'Allow')
        $acl.AddAccessRule($ruleAdmin)
        $acl.AddAccessRule($ruleSystem)
        $current = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        if ($current) {
            $ruleUser = New-Object System.Security.AccessControl.FileSystemAccessRule($current, 'Read', 'Allow')
            $acl.AddAccessRule($ruleUser)
        }
        Set-Acl -Path $FilePath -AclObject $acl
    }
    catch {
        Write-Verbose "ACL hardening skipped: $($_.Exception.Message)"
    }
}

function Save-LaunchContext {
    if (-not (Test-Path $script:EditIEContextDir)) {
        New-Item -ItemType Directory -Path $script:EditIEContextDir -Force | Out-Null
    }

    $launcher = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if ($launcher.IsSystem) {
        throw 'Cannot save launch context as SYSTEM without an interactive launcher.'
    }

    $ctx = Get-InteractiveUserContext -AllowUnresolved:$false
    $runId = [guid]::NewGuid().ToString('D')
    $now = Get-Date
    $payload = @{
        runId           = $runId
        capturedAt      = $now.ToString('o')
        expiresAt       = $now.AddMinutes((Get-EditIEContextMaxAgeMinutes)).ToString('o')
        userName        = $ctx.UserName
        userSid         = $ctx.UserSid
        sessionId       = $ctx.SessionId
        launcherSid     = $launcher.User.Value
        launcherName    = $launcher.Name
        launcherPid     = $PID
    }

    $path = Join-Path $script:EditIEContextDir "$runId.json"
    $json = $payload | ConvertTo-Json -Depth 4
    Set-Content -Path $path -Value $json -Encoding UTF8 -Force
    Set-ContextFileAcl -FilePath $path

    if (-not (Test-Path $path)) { throw "Failed to write launch context to $path" }

    return $runId
}

function Get-ValidatedLaunchContext {
    param([Parameter(Mandatory)][string]$RunId)

    if ([string]::IsNullOrWhiteSpace($RunId)) { throw 'Missing run id for elevated session.' }

    $path = Join-Path $script:EditIEContextDir "$RunId.json"
    if (-not (Test-Path $path)) { throw "Launch context not found or expired (missing file for run $RunId)." }

    try {
        $saved = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Launch context file is invalid: $path"
    }

    if (-not (Test-LaunchContextRunId -ExpectedRunId $RunId -ActualRunId ([string]$saved.runId))) {
        throw 'Launch context run id mismatch.'
    }

    $captured = [datetime]::Parse([string]$saved.capturedAt, $null, [Globalization.DateTimeStyles]::RoundtripKind)
    if (-not (Test-LaunchContextFreshness -CapturedAt $captured -Now (Get-Date))) {
        throw 'Launch context expired. Run the batch file again without reusing an old elevation.'
    }

    if ([string]$saved.userSid -ne [string]$saved.launcherSid) {
        Write-EditIELog "Launch context: launcher SID differs from target user SID (launcher=$($saved.launcherSid) target=$($saved.userSid))" 'WARN'
    }

    return [pscustomobject]@{
        UserName     = [string]$saved.userName
        UserSid      = [string]$saved.userSid
        RunId        = [string]$saved.runId
        Source       = 'LaunchContext'
        Resolved     = $true
        LauncherSid  = [string]$saved.launcherSid
        LauncherName = [string]$saved.launcherName
    }
}

function Get-TargetUserContext {
    param([string]$RunId)

    if ($RunId) {
        return Get-ValidatedLaunchContext -RunId $RunId
    }

    $elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($elevated) {
        throw 'Elevated session requires /RunId from the non-elevated launcher. Start the .bat normally (not from an elevated prompt).'
    }
    return Get-InteractiveUserContext
}

function Test-UserHiveLoaded { param([string]$UserSid) Test-Path "Registry::HKEY_USERS\$UserSid\Software" }

function Get-UserRegistryMount {
    param([string]$UserSid)
    if (Test-UserHiveLoaded -UserSid $UserSid) {
        return [pscustomobject]@{ HivePrefix = "HKU:\$UserSid"; RegPrefix = "HKU\$UserSid"; Loaded = $true }
    }
    throw "Registry hive for SID $UserSid is not loaded. Keep the user session active and retry."
}

function ConvertTo-RegExePath {
    param([string]$HivePrefix, [string]$SubKey)
    if ($HivePrefix -like 'HKU:*') { return "HKU\$($HivePrefix -replace '^HKU:\\','')\$SubKey" }
    if ($HivePrefix -like 'HKLM:*') { return "HKLM\$SubKey" }
    if ($HivePrefix -like 'HKCU:*') { return "HKCU\$SubKey" }
    return "$HivePrefix\$SubKey"
}

function New-EditIEResult {
    param(
        [string]$Label,
        [string]$Status,
        [string]$Detail = '',
        [bool]$Required = $false,
        [string]$Category = 'General'
    )
    return [pscustomobject]@{ Label = $Label; Status = $Status; Detail = $Detail; Required = $Required; Category = $Category }
}

function Invoke-EditIERegistry {
    param(
        [ValidateSet('Add', 'Delete')][string]$Operation,
        [string]$HivePrefix,
        [string]$SubKey,
        [string]$Name,
        [string]$Type = 'REG_DWORD',
        [string]$Data,
        [string]$SettingLabel,
        [bool]$Required = $false,
        [string]$Category = 'General'
    )

    $regPath = ConvertTo-RegExePath -HivePrefix $HivePrefix -SubKey $SubKey
    $label = if ($SettingLabel) { $SettingLabel } else { "$regPath\$Name" }

    if ($Operation -eq 'Add') {
        $r = Invoke-RegExe -Arguments @('add', $regPath, '/v', $Name, '/t', $Type, '/d', $Data, '/f')
    }
    elseif ([string]::IsNullOrWhiteSpace($Name)) {
        $r = Invoke-RegExe -Arguments @('delete', $regPath, '/f')
    }
    else {
        $r = Invoke-RegExe -Arguments @('delete', $regPath, '/v', $Name, '/f')
    }

    if ($r.ExitCode -ne 0) {
        Write-EditIELog "$label -> Failed ($($r.Output))" 'ERROR'
        return (New-EditIEResult -Label $label -Status 'Failed' -Detail $r.Output -Required:$Required -Category $Category)
    }

    if ($Operation -eq 'Add') {
        $q = Invoke-RegQueryValue -HivePrefix $HivePrefix -SubKey $SubKey -Name $Name
        if ($q.Status -ne 'Found') {
            Write-EditIELog "$label -> Failed verification ($($q.Status): $($q.Message))" 'ERROR'
            return (New-EditIEResult -Label $label -Status 'Failed' -Detail $q.Message -Required:$Required -Category $Category)
        }
        $expected = if ($Type -eq 'REG_DWORD') { [int]$Data } else { $Data }
        if ($Type -ne 'REG_DWORD') { $ok = ("$($q.Value)" -eq "$expected") }
        else { $ok = ([int]$q.Value -eq [int]$expected) }
        if (-not $ok) {
            return (New-EditIEResult -Label $label -Status 'Failed' -Detail "Expected $expected got $($q.Value)" -Required:$Required -Category $Category)
        }
    }
    else {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            $tk = Invoke-RegTestKey -HivePrefix $HivePrefix -SubKey $SubKey
            if ($tk.Status -eq 'Found') {
                return (New-EditIEResult -Label $label -Status 'Failed' -Detail 'Key still present' -Required:$Required -Category $Category)
            }
        }
        else {
            $q = Invoke-RegQueryValue -HivePrefix $HivePrefix -SubKey $SubKey -Name $Name
            if ($q.Status -eq 'Found') {
                return (New-EditIEResult -Label $label -Status 'Failed' -Detail 'Value still present' -Required:$Required -Category $Category)
            }
        }
    }

    Write-EditIELog "$label -> Success" 'OK'
    return (New-EditIEResult -Label $label -Status 'Success' -Required:$Required -Category $Category)
}

function Get-SecureProtocolsPolicyBlock {
    param([Parameter(Mandatory)][string]$TargetUserSid)

    $blocks = @()
    $hklm = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings'
    if (Test-Path $hklm) {
        $prop = Get-ItemProperty -Path $hklm -Name SecureProtocols -ErrorAction SilentlyContinue
        if ($null -ne $prop -and $null -ne $prop.SecureProtocols) {
            $blocks += [pscustomobject]@{ Path = $hklm; Value = [int]$prop.SecureProtocols }
        }
    }

    $userPolicySub = 'Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings'
    $userHive = "HKU:\$TargetUserSid"
    $q = Invoke-RegQueryValue -HivePrefix $userHive -SubKey $userPolicySub -Name 'SecureProtocols'
    if ($q.Status -eq 'Found') {
        $blocks += [pscustomobject]@{
            Path  = "HKU\$TargetUserSid\$userPolicySub"
            Value = [int]$q.Value
        }
    }
    elseif ($q.Status -eq 'AccessDenied') {
        Write-EditIELog "Access denied reading user policy SecureProtocols for $TargetUserSid" 'WARN'
    }
    return $blocks
}

function Get-AdvancedCryptoOptions {
    $root = 'HKLM:\Software\Microsoft\Internet Explorer\AdvancedOptions\CRYPTO'
    $options = @()
    if (-not (Test-Path $root)) { return $options }
    Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $checked = Get-ItemProperty -Path $_.PSPath -Name 'CheckedValue' -ErrorAction SilentlyContinue
        $text = Get-ItemProperty -Path $_.PSPath -Name 'Text' -ErrorAction SilentlyContinue
        if ($null -ne $checked.CheckedValue) {
            $options += [pscustomobject]@{
                Name = $_.PSChildName; Text = [string]$text.Text; CheckedValue = [int]$checked.CheckedValue
            }
        }
    }
    return $options
}

function Measure-Tls13RuntimeSupport {
    $os = Get-OsBuildInfo
    $crypto = Get-AdvancedCryptoOptions
    $cryptoTls13 = Get-CryptoUiTls13Present -CryptoOptions $crypto

    $schannelKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client'
    $keyExists = Test-Path $schannelKey
    $enabled = $null
    $disabledByDefault = $null
    if ($keyExists) {
        $e = Get-ItemProperty -Path $schannelKey -Name 'Enabled' -ErrorAction SilentlyContinue
        $d = Get-ItemProperty -Path $schannelKey -Name 'DisabledByDefault' -ErrorAction SilentlyContinue
        if ($null -ne $e) { $enabled = [int]$e.Enabled }
        if ($null -ne $d) { $disabledByDefault = [int]$d.DisabledByDefault }
    }

    $assessment = Get-Tls13SupportAssessment -OsBuild $os.Build -IsWindows11OrLater $os.IsWindows11OrLater `
        -CryptoUiTls13Present $cryptoTls13 -SchannelEnabled $enabled -SchannelDisabledByDefault $disabledByDefault -SchannelKeyExists $keyExists

    Write-EditIELog ("TLS 1.3 assessment: {0} — {1}" -f $assessment.Status, ($assessment.Reasons -join '; ')) $(if ($assessment.Status -eq 'Supported') { 'INFO' } elseif ($assessment.Status -eq 'Unsupported') { 'UNSUPPORTED' } else { 'SKIP' })
    return $assessment
}

function Add-CryptoProtocolBits {
    param(
        [object[]]$CryptoOptions, [string[]]$Patterns, [int]$FallbackBit, [string]$Label,
        [ref]$MaskRef, [System.Collections.Generic.List[string]]$IncludedRef
    )
    $local = 0; $matched = $false
    foreach ($opt in $CryptoOptions) {
        $blob = ($opt.Name + ' ' + $opt.Text).ToLowerInvariant()
        foreach ($p in $Patterns) {
            if ($blob -match $p) { $local = $local -bor [int]$opt.CheckedValue; $matched = $true }
        }
    }
    if (-not $matched) { $local = $FallbackBit }
    if ($local -ne 0) { $MaskRef.Value = $MaskRef.Value -bor $local; $IncludedRef.Add($Label) | Out-Null }
}

function Get-SecureProtocolsMask {
    param([switch]$LegacyTls)

    $crypto = Get-AdvancedCryptoOptions
    $included = New-Object System.Collections.Generic.List[string]
    $maskAcc = 0
    $tls13 = Measure-Tls13RuntimeSupport

    Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('tls 1.2', 'tls1.2') -FallbackBit $script:SecureProtocolBits.Tls12Client -Label 'TLS 1.2' -MaskRef ([ref]$maskAcc) -IncludedRef $included

    if ($tls13.Status -eq 'Supported') {
        Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('tls 1.3', 'tls1.3') -FallbackBit $script:SecureProtocolBits.Tls13Client -Label 'TLS 1.3' -MaskRef ([ref]$maskAcc) -IncludedRef $included
    }
    else {
        Write-EditIELog "TLS 1.3 not added to SecureProtocols ($($tls13.Status))" 'SKIP'
    }

    if ($LegacyTls) {
        Write-EditIELog 'Legacy TLS mode — weak protocols enabled' 'WARN'
        Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('ssl 3.0', 'ssl3') -FallbackBit $script:SecureProtocolBits.Ssl3Client -Label 'SSL 3.0 (legacy)' -MaskRef ([ref]$maskAcc) -IncludedRef $included
        Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('tls 1.0', 'tls1.0') -FallbackBit $script:SecureProtocolBits.Tls10Client -Label 'TLS 1.0 (legacy)' -MaskRef ([ref]$maskAcc) -IncludedRef $included
        Add-CryptoProtocolBits -CryptoOptions $crypto -Patterns @('tls 1.1', 'tls1.1') -FallbackBit $script:SecureProtocolBits.Tls11Client -Label 'TLS 1.1 (legacy)' -MaskRef ([ref]$maskAcc) -IncludedRef $included
    }

    $mask = $maskAcc -band 0x0000FFFF
    return [pscustomobject]@{
        Value = $mask; Hex = ('0x{0:X}' -f $mask); Protocols = [string[]]$included; Tls13Assessment = $tls13
    }
}

function Confirm-SecureProtocolsForUser {
    param(
        [string]$UserHivePrefix,
        [int]$ExpectedMask
    )
    $q = Invoke-RegQueryValue -HivePrefix $UserHivePrefix -SubKey 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name 'SecureProtocols'
    if ($q.Status -ne 'Found') {
        return (New-EditIEResult -Label 'Verify SecureProtocols (Advanced alignment)' -Status 'Failed' -Detail $q.Message -Required $true -Category 'Verify')
    }
    if (-not (Test-SecureProtocolsMaskAlignment -ExpectedMask $ExpectedMask -ActualMask ([int]$q.Value))) {
        return (New-EditIEResult -Label 'Verify SecureProtocols (Advanced alignment)' -Status 'Failed' -Detail "Expected $ExpectedMask got $($q.Value)" -Required $true -Category 'Verify')
    }
    return (New-EditIEResult -Label 'Verify SecureProtocols (Advanced alignment)' -Status 'Success' -Required $true -Category 'Verify')
}

function Set-SchannelLegacyClientProtocols {
    $results = New-Object System.Collections.Generic.List[object]
    foreach ($proto in $script:SchannelLegacyProtocols) {
        $sub = "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$proto\Client"
        $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey $sub -Name 'Enabled' -Data '1' -SettingLabel "Schannel $proto Client Enabled" -Required $true -Category 'Schannel')) | Out-Null
        $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey $sub -Name 'DisabledByDefault' -Data '0' -SettingLabel "Schannel $proto Client DisabledByDefault" -Required $true -Category 'Schannel')) | Out-Null
    }
    return $results
}

function Get-UserBackupPath { param([string]$UserSid) Join-Path $script:EditIEBackupDir "backup_user_$UserSid.json" }

function Export-RegistrySnapshotEntry {
    param([string]$HivePrefix, [string]$SubKey, [string]$Name, [string]$Type = 'REG_DWORD')
    $tk = Invoke-RegTestKey -HivePrefix $HivePrefix -SubKey $SubKey
    $keyExists = ($tk.Status -eq 'Found')
    $hadValue = $false; $value = $null
    if ($keyExists) {
        $q = Invoke-RegQueryValue -HivePrefix $HivePrefix -SubKey $SubKey -Name $Name
        if ($q.Status -eq 'Found') { $hadValue = $true; $value = $q.Value }
        elseif ($q.Status -eq 'AccessDenied') { throw "Access denied reading $SubKey\$Name" }
    }
    return [pscustomobject]@{
        hivePrefix = $HivePrefix; subKey = $SubKey; name = $Name; type = $Type
        value = $value; existed = $hadValue; keyExisted = $keyExists; scope = 'User'
    }
}

function Backup-SitesXml {
    $backupFile = Join-Path $script:EditIEBackupDir 'sites.xml.bak'
    if (Test-Path $script:EditIESitesXml) {
        Copy-Item -Path $script:EditIESitesXml -Destination $backupFile -Force
        return $true
    }
    return $false
}

function Initialize-UserSettingsBackup {
    param([string]$UserSid, [string]$UserHivePrefix)

    if (-not (Test-Path $script:EditIEBackupDir)) { New-Item -ItemType Directory -Path $script:EditIEBackupDir -Force | Out-Null }
    $backupPath = Get-UserBackupPath -UserSid $UserSid
    if (Test-Path $backupPath) {
        Write-EditIELog "User backup exists: $backupPath" 'INFO'
        return
    }

    Write-EditIELog "Creating user backup for SID $UserSid" 'INFO'
    $entries = @()
    $trustedBase = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir'
    $entries += [pscustomobject]@{
        hivePrefix = $UserHivePrefix; subKey = $trustedBase; name = '__KEY__'; type = 'REG_KEY'
        value = $null; existed = (Test-RegistryKeyExists -HivePrefix $UserHivePrefix -SubKey $trustedBase)
        keyExisted = (Test-RegistryKeyExists -HivePrefix $UserHivePrefix -SubKey $trustedBase); scope = 'User'
    }
    foreach ($sub in @('at', 'oa1', 'oa2', 'oa3', 'oa4')) {
        foreach ($proto in @('http', 'https')) {
            $e = Export-RegistrySnapshotEntry -HivePrefix $UserHivePrefix -SubKey "$trustedBase\$sub" -Name $proto
            $e.scope = 'User'; $entries += $e
        }
    }
    $e = Export-RegistrySnapshotEntry -HivePrefix $UserHivePrefix -SubKey 'Software\Microsoft\Internet Explorer\New Windows' -Name 'PopupMgr'
    $e.scope = 'User'; $entries += $e
    $e = Export-RegistrySnapshotEntry -HivePrefix $UserHivePrefix -SubKey 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name 'SecureProtocols'
    $e.scope = 'User'; $entries += $e
    $e = Export-RegistrySnapshotEntry -HivePrefix $UserHivePrefix -SubKey 'Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing' -Name 'State'
    $e.scope = 'User'; $entries += $e

    $payload = @{
        version = 3; scope = 'User'; createdAt = (Get-Date).ToString('o'); userSid = $UserSid
        entries = @($entries | ForEach-Object { @{ hivePrefix = $_.hivePrefix; subKey = $_.subKey; name = $_.name; type = $_.type; value = $_.value; existed = $_.existed; keyExisted = $_.keyExisted; scope = $_.scope } })
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $backupPath -Encoding UTF8
    Write-EditIELog "User backup: $backupPath" 'OK'
}

function Initialize-MachineSettingsBackup {
    param([string]$OwnerUserSid)

    if (-not (Test-Path $script:EditIEBackupDir)) { New-Item -ItemType Directory -Path $script:EditIEBackupDir -Force | Out-Null }

    if (Test-Path $script:EditIEMachineBackup) {
        $existing = Get-Content $script:EditIEMachineBackup -Raw | ConvertFrom-Json
        if ($existing.ownerUserSid -and [string]$existing.ownerUserSid -ne $OwnerUserSid) {
            Write-EditIELog "Machine backup owned by $($existing.ownerUserSid); skipping HKLM snapshot for $OwnerUserSid" 'WARN'
            return $false
        }
    }

    $entries = @()
    foreach ($path in @(
            'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
            'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
        )) {
        $e = Export-RegistrySnapshotEntry -HivePrefix 'HKLM:' -SubKey $path -Name 'DefaultSecureProtocols'
        $e.scope = 'Machine'; $entries += $e
    }
    foreach ($n in @('InternetExplorerIntegrationLevel', 'InternetExplorerIntegrationSiteList')) {
        $e = Export-RegistrySnapshotEntry -HivePrefix 'HKLM:' -SubKey 'SOFTWARE\Policies\Microsoft\Edge' -Name $n -Type $(if ($n -like '*SiteList*') { 'REG_SZ' } else { 'REG_DWORD' })
        $e.scope = 'Machine'; $entries += $e
    }
    foreach ($proto in @('SSL 3.0', 'TLS 1.0', 'TLS 1.1', 'TLS 1.2', 'TLS 1.3')) {
        $base = "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$proto\Client"
        foreach ($vn in @('Enabled', 'DisabledByDefault')) {
            $e = Export-RegistrySnapshotEntry -HivePrefix 'HKLM:' -SubKey $base -Name $vn
            $e.scope = 'Machine'; $entries += $e
        }
    }

    $sitesBacked = Backup-SitesXml
    $payload = @{
        version = 3; scope = 'Machine'; createdAt = (Get-Date).ToString('o'); ownerUserSid = $OwnerUserSid
        sitesXmlBackedUp = $sitesBacked
        entries = @($entries | ForEach-Object { @{ hivePrefix = $_.hivePrefix; subKey = $_.subKey; name = $_.name; type = $_.type; value = $_.value; existed = $_.existed; keyExisted = $_.keyExisted; scope = $_.scope } })
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $script:EditIEMachineBackup -Encoding UTF8
    Write-EditIELog "Machine backup: $script:EditIEMachineBackup (owner $OwnerUserSid)" 'OK'
    return $true
}

function Restore-BackupEntries {
    param(
        [object[]]$Entries,
        [string]$UserHivePrefix,
        [string]$ScopeLabel
    )
    $results = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $Entries) {
        $hive = [string]$entry.hivePrefix
        if ($hive -like 'HKU:*') { $hive = $UserHivePrefix }
        $sub = [string]$entry.subKey; $name = [string]$entry.name

        if ($name -eq '__KEY__' -and $entry.type -eq 'REG_KEY') {
            if (-not [bool]$entry.keyExisted) {
                if ((Invoke-RegTestKey -HivePrefix $hive -SubKey $sub).Status -eq 'Found') {
                    $results.Add((Invoke-EditIERegistry -Operation Delete -HivePrefix $hive -SubKey $sub -Name '' -SettingLabel "$ScopeLabel remove key $sub" -Required $true -Category 'Restore')) | Out-Null
                }
                else {
                    $results.Add((New-EditIEResult -Label "$ScopeLabel key $sub" -Status 'Skipped' -Detail 'Already absent')) | Out-Null
                }
            }
            continue
        }

        if (-not [bool]$entry.existed) {
            $q = Invoke-RegQueryValue -HivePrefix $hive -SubKey $sub -Name $name
            if ($q.Status -eq 'Found') {
                $results.Add((Invoke-EditIERegistry -Operation Delete -HivePrefix $hive -SubKey $sub -Name $name -SettingLabel "$ScopeLabel delete $sub\$name" -Required $true -Category 'Restore')) | Out-Null
            }
            else {
                $results.Add((New-EditIEResult -Label "$ScopeLabel $sub\$name" -Status 'Skipped' -Detail 'Not present before backup')) | Out-Null
            }
        }
        else {
            $type = if ($entry.type) { [string]$entry.type } else { 'REG_DWORD' }
            $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix $hive -SubKey $sub -Name $name -Type $type -Data ([string]$entry.value) -SettingLabel "$ScopeLabel restore $sub\$name" -Required $true -Category 'Restore')) | Out-Null
        }
    }
    return $results
}

function Restore-UserSettingsFromBackup {
    param([string]$UserSid, [string]$UserHivePrefix)
    $backupPath = Get-UserBackupPath -UserSid $UserSid
    if (-not (Test-Path $backupPath)) { throw "No user backup at $backupPath" }
    $backup = Get-Content $backupPath -Raw | ConvertFrom-Json
    return Restore-BackupEntries -Entries $backup.entries -UserHivePrefix $UserHivePrefix -ScopeLabel 'User'
}

function Restore-MachineSettingsFromBackup {
    param([string]$RequestingUserSid, [string]$UserHivePrefix)

    if (-not (Test-Path $script:EditIEMachineBackup)) {
        Write-EditIELog 'No machine backup — HKLM restore skipped' 'SKIP'
        return @((New-EditIEResult -Label 'Machine HKLM restore' -Status 'Skipped' -Detail 'No machine backup file'))
    }

    $backup = Get-Content $script:EditIEMachineBackup -Raw | ConvertFrom-Json
    if ($backup.ownerUserSid -and [string]$backup.ownerUserSid -ne $RequestingUserSid) {
        Write-EditIELog "Machine backup owned by $($backup.ownerUserSid); not restoring HKLM for $RequestingUserSid" 'WARN'
        return @((New-EditIEResult -Label 'Machine HKLM restore' -Status 'Skipped' -Detail 'Machine backup belongs to another user SID'))
    }

    $results = Restore-BackupEntries -Entries $backup.entries -UserHivePrefix $UserHivePrefix -ScopeLabel 'Machine'
    $bakSites = Join-Path $script:EditIEBackupDir 'sites.xml.bak'
    if ([bool]$backup.sitesXmlBackedUp -and (Test-Path $bakSites)) {
        Copy-Item -Path $bakSites -Destination $script:EditIESitesXml -Force
        $results.Add((New-EditIEResult -Label 'Restore sites.xml' -Status 'Success' -Required $true -Category 'Restore')) | Out-Null
    }
    return $results
}

function Show-EditIESummary {
    param([object[]]$Results, [string[]]$Notes = @())
    Write-Host ''; Write-Host '----------------------------------------------------------'; Write-Host ' Summary'; Write-Host '----------------------------------------------------------'
    $Results | Group-Object Status | ForEach-Object { Write-Host (" {0}: {1}" -f $_.Name, $_.Count) }
    foreach ($n in $Notes) { Write-Host " Note: $n" }
    if ($script:LogFilePath) { Write-Host " Log: $script:LogFilePath" }
    Write-Host '----------------------------------------------------------'
}

# Backward-compatible alias
function Initialize-SettingsBackup {
    param([string]$UserSid, [string]$UserHivePrefix)
    Initialize-UserSettingsBackup -UserSid $UserSid -UserHivePrefix $UserHivePrefix | Out-Null
    Initialize-MachineSettingsBackup -OwnerUserSid $UserSid | Out-Null
}

function Restore-SettingsFromBackup {
    param([string]$UserSid, [string]$UserHivePrefix)
    $all = New-Object System.Collections.Generic.List[object]
    foreach ($r in (Restore-UserSettingsFromBackup -UserSid $UserSid -UserHivePrefix $UserHivePrefix)) { $all.Add($r) | Out-Null }
    foreach ($r in (Restore-MachineSettingsFromBackup -RequestingUserSid $UserSid -UserHivePrefix $UserHivePrefix)) { $all.Add($r) | Out-Null }
    return $all
}
