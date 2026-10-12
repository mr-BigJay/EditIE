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
$script:EditIESessionDir = Join-Path $env:ProgramData 'GUMS-EditIE\sessions'
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
            if ($r.Output -match '(?i)unable to find|cannot find|not find') {
                return [pscustomobject]@{ Status = 'NotFound'; Value = $null; Message = $r.Output }
            }
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
    if ($r.Output -match '(?i)unable to find|cannot find|not find|error.*not found') {
        return [pscustomobject]@{ Status = 'NotFound'; Value = $null; Message = $r.Output }
    }
    if ($r.ExitCode -ne 0 -and $r.Output -match '(?i)invalid syntax|incorrect function') {
        return [pscustomobject]@{ Status = 'Error'; Value = $null; Message = $r.Output }
    }
    return [pscustomobject]@{ Status = 'Error'; Value = $null; Message = if ($r.Output) { $r.Output } else { "reg query exit code $($r.ExitCode)" } }
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
    if ($r.Output -match '(?i)unable to find|cannot find|not find') {
        return [pscustomobject]@{ Status = 'NotFound'; Message = $r.Output }
    }
    return [pscustomobject]@{ Status = 'Error'; Message = if ($r.Output) { $r.Output } else { "reg query exit code $($r.ExitCode)" } }
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
    if ($current.IsSystem -and -not $AllowUnresolved) {
        throw 'Running as SYSTEM without a validated launch context. Run from the target user session (fail-safe).'
    }

    $sid = $current.User.Value
    if (-not $sid -and $AllowUnresolved) {
        return [pscustomobject]@{
            UserName = $current.Name; UserSid = $null; IsSystem = $current.IsSystem; Resolved = $false
        }
    }
    if (-not $sid) {
        throw 'Could not resolve the launching user SID from WindowsIdentity.GetCurrent().'
    }

    return [pscustomobject]@{
        UserName  = $current.Name
        UserSid   = $sid
        IsSystem  = $current.IsSystem
        Resolved  = $true
    }
}

function Assert-LauncherTargetIdentity {
    param(
        [string]$LauncherSid,
        [string]$TargetUserSid
    )
    if (-not (Test-LauncherTargetSidMatch -LauncherSid $LauncherSid -TargetUserSid $TargetUserSid)) {
        throw "Launcher SID ($LauncherSid) differs from target user SID ($TargetUserSid). Refusing to change another user's settings (RDP/multi-user safety)."
    }
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
        throw "Failed to set launch context ACL on ${FilePath}: $($_.Exception.Message)"
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

    $launcherSid = $launcher.User.Value
    if (-not $launcherSid) { throw 'Launching process has no user SID.' }

    $runId = [guid]::NewGuid().ToString('D')
    $now = Get-Date
    $payload = @{
        runId                = $runId
        capturedAt           = $now.ToString('o')
        elevationExpiresAt   = $now.AddMinutes((Get-EditIEContextElevationMaxAgeMinutes)).ToString('o')
        userName             = $launcher.Name
        userSid              = $launcherSid
        launcherSid          = $launcherSid
        launcherName         = $launcher.Name
        launcherPid          = $PID
    }

    $path = Join-Path $script:EditIEContextDir "$runId.json"
    $json = $payload | ConvertTo-Json -Depth 4
    Set-Content -Path $path -Value $json -Encoding UTF8 -Force
    Set-ContextFileAcl -FilePath $path

    if (-not (Test-Path $path)) { throw "Failed to write launch context to $path" }

    return $runId
}

function Register-EditIEMenuSession {
    param([Parameter(Mandatory)][string]$RunId)

    if (-not (Test-Path $script:EditIESessionDir)) {
        New-Item -ItemType Directory -Path $script:EditIESessionDir -Force | Out-Null
    }
    $validUntil = (Get-Date).AddHours((Get-EditIESessionMaxAgeHours))
    $payload = @{
        runId      = $RunId
        startedAt  = (Get-Date).ToString('o')
        validUntil = $validUntil.ToString('o')
    }
    $sessionPath = Join-Path $script:EditIESessionDir "$RunId.session.json"
    $payload | ConvertTo-Json | Set-Content -Path $sessionPath -Encoding UTF8 -Force
}

function Test-EditIEMenuSessionValid {
    param([Parameter(Mandatory)][string]$RunId)

    $sessionPath = Join-Path $script:EditIESessionDir "$RunId.session.json"
    if (-not (Test-Path $sessionPath)) { return $false }
    try {
        $s = Get-Content $sessionPath -Raw | ConvertFrom-Json
        $until = [datetime]::Parse([string]$s.validUntil, $null, [Globalization.DateTimeStyles]::RoundtripKind)
        return (Test-EditIEMenuSessionFreshness -ValidUntil $until -Now (Get-Date))
    }
    catch {
        return $false
    }
}

function Get-ValidatedLaunchContext {
    param([Parameter(Mandatory)][string]$RunId)

    if ([string]::IsNullOrWhiteSpace($RunId)) { throw 'Missing run id for elevated session.' }

    $path = Join-Path $script:EditIEContextDir "$RunId.json"
    if (-not (Test-Path $path)) { throw "Launch context not found (missing file for run $RunId)." }

    try {
        $saved = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Launch context file is invalid: $path"
    }

    if (-not (Test-LaunchContextRunId -ExpectedRunId $RunId -ActualRunId ([string]$saved.runId))) {
        throw 'Launch context run id mismatch.'
    }

    Assert-LauncherTargetIdentity -LauncherSid ([string]$saved.launcherSid) -TargetUserSid ([string]$saved.userSid)

    $menuSessionOk = Test-EditIEMenuSessionValid -RunId $RunId
    if (-not $menuSessionOk) {
        $captured = [datetime]::Parse([string]$saved.capturedAt, $null, [Globalization.DateTimeStyles]::RoundtripKind)
        if (-not (Test-LaunchContextElevationFreshness -CapturedAt $captured -Now (Get-Date))) {
            throw 'Launch context elevation window expired and no active menu session. Close and restart the batch file.'
        }
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
    if ($tk.Status -eq 'AccessDenied') {
        throw "Access denied opening registry key $HivePrefix\$SubKey"
    }
    if ($tk.Status -eq 'Error') {
        throw "Registry error opening key $HivePrefix\$SubKey`: $($tk.Message)"
    }
    $keyExists = ($tk.Status -eq 'Found')
    $hadValue = $false; $value = $null
    if ($keyExists) {
        $q = Invoke-RegQueryValue -HivePrefix $HivePrefix -SubKey $SubKey -Name $Name
        if ($q.Status -eq 'Found') { $hadValue = $true; $value = $q.Value }
        elseif ($q.Status -eq 'AccessDenied') { throw "Access denied reading $SubKey\$Name" }
        elseif ($q.Status -eq 'Error') { throw "Registry error reading $SubKey\$Name`: $($q.Message)" }
    }
    return [pscustomobject]@{
        hivePrefix = $HivePrefix; subKey = $SubKey; name = $Name; type = $Type
        value = $value; existed = $hadValue; keyExisted = $keyExists; scope = 'User'
    }
}

function Get-SitesXmlBackupPath { Join-Path $script:EditIEBackupDir 'sites.xml.bak' }

function Backup-SitesXmlIfMissing {
    $backupFile = Get-SitesXmlBackupPath
    if (Test-SitesXmlBackupImmutable -BackupAlreadyExists (Test-Path $backupFile)) {
        return [pscustomobject]@{ BackedUp = (Test-Path $backupFile); ExistedAtBackup = $null; SkippedOverwrite = $true }
    }
    $existed = Test-Path $script:EditIESitesXml
    if ($existed) {
        Copy-Item -Path $script:EditIESitesXml -Destination $backupFile -Force
    }
    return [pscustomobject]@{
        BackedUp          = $existed
        ExistedAtBackup   = $existed
        SkippedOverwrite  = $false
    }
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

function Test-MachineBackupFileValid {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    try {
        $j = Get-Content $Path -Raw | ConvertFrom-Json
        return ($null -ne $j.version -and $null -ne $j.entries)
    }
    catch { return $false }
}

function Initialize-MachineSettingsBackup {
    param([string]$OwnerUserSid)

    if (-not (Test-Path $script:EditIEBackupDir)) { New-Item -ItemType Directory -Path $script:EditIEBackupDir -Force | Out-Null }

    if (Test-MachineBackupShouldSkipCreate -BackupFileExists (Test-Path $script:EditIEMachineBackup) -BackupValid (Test-MachineBackupFileValid -Path $script:EditIEMachineBackup)) {
        Write-EditIELog "Machine backup already exists — not overwriting ($script:EditIEMachineBackup)" 'INFO'
        return $false
    }

    if (Test-Path $script:EditIEMachineBackup) {
        $existing = Get-Content $script:EditIEMachineBackup -Raw | ConvertFrom-Json
        if ($existing.ownerUserSid -and [string]$existing.ownerUserSid -ne $OwnerUserSid) {
            Write-EditIELog "Machine backup owned by $($existing.ownerUserSid); skipping new HKLM snapshot for $OwnerUserSid" 'WARN'
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

    $sitesInfo = Backup-SitesXmlIfMissing
    $payload = @{
        version = 4; scope = 'Machine'; createdAt = (Get-Date).ToString('o'); ownerUserSid = $OwnerUserSid
        sitesXmlBackedUp = [bool]$sitesInfo.BackedUp
        sitesXmlExistedAtBackup = [bool]$sitesInfo.ExistedAtBackup
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
            if ($q.Status -eq 'AccessDenied' -or $q.Status -eq 'Error') {
                $results.Add((New-EditIEResult -Label "$ScopeLabel $sub\$name" -Status 'Failed' -Detail $q.Message -Required $true -Category 'Restore')) | Out-Null
            }
            elseif ($q.Status -eq 'Found') {
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
    param(
        [string]$RequestingUserSid,
        [string]$UserHivePrefix,
        [ref]$PartialRestore
    )

    $list = New-Object System.Collections.Generic.List[object]

    if (-not (Test-Path $script:EditIEMachineBackup)) {
        Write-EditIELog 'No machine backup — HKLM restore skipped' 'SKIP'
        $PartialRestore.Value = $true
        $list.Add((New-EditIEResult -Label 'Machine HKLM restore' -Status 'Skipped' -Detail 'No machine backup file' -Required $false)) | Out-Null
        return $list
    }

    $backup = Get-Content $script:EditIEMachineBackup -Raw | ConvertFrom-Json
    if ($backup.ownerUserSid -and [string]$backup.ownerUserSid -ne $RequestingUserSid) {
        Write-EditIELog "Machine backup owned by $($backup.ownerUserSid); not restoring HKLM for $RequestingUserSid" 'WARN'
        $PartialRestore.Value = $true
        $list.Add((New-EditIEResult -Label 'Machine HKLM restore' -Status 'Skipped' -Detail 'Machine backup belongs to another user SID' -Required $false)) | Out-Null
        return $list
    }

    foreach ($r in (Restore-BackupEntries -Entries @($backup.entries) -UserHivePrefix $UserHivePrefix -ScopeLabel 'Machine')) {
        $list.Add($r) | Out-Null
    }

    $bakSites = Get-SitesXmlBackupPath
    $existedAtBackup = $false
    if ($null -ne $backup.PSObject.Properties['sitesXmlExistedAtBackup']) {
        $existedAtBackup = [bool]$backup.sitesXmlExistedAtBackup
    }
    elseif ([bool]$backup.sitesXmlBackedUp) {
        $existedAtBackup = $true
    }

    if ($existedAtBackup -and (Test-Path $bakSites)) {
        Copy-Item -Path $bakSites -Destination $script:EditIESitesXml -Force
        $list.Add((New-EditIEResult -Label 'Restore sites.xml' -Status 'Success' -Required $true -Category 'Restore')) | Out-Null
    }
    elseif (-not $existedAtBackup) {
        if (Test-Path $script:EditIESitesXml) {
            Remove-Item -Path $script:EditIESitesXml -Force -ErrorAction Stop
            $list.Add((New-EditIEResult -Label 'Remove sites.xml (not present before backup)' -Status 'Success' -Required $true -Category 'Restore')) | Out-Null
        }
        else {
            $list.Add((New-EditIEResult -Label 'sites.xml' -Status 'Skipped' -Detail 'Already absent')) | Out-Null
        }
    }
    return $list
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
    param(
        [string]$UserSid,
        [string]$UserHivePrefix,
        [ref]$PartialRestore
    )
    $all = New-Object System.Collections.Generic.List[object]
    foreach ($r in (Restore-UserSettingsFromBackup -UserSid $UserSid -UserHivePrefix $UserHivePrefix)) { $all.Add($r) | Out-Null }
    foreach ($r in (Restore-MachineSettingsFromBackup -RequestingUserSid $UserSid -UserHivePrefix $UserHivePrefix -PartialRestore $PartialRestore)) {
        $all.Add($r) | Out-Null
    }
    return $all
}
