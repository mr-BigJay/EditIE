#Requires -Version 5.1
Set-StrictMode -Version Latest

function Get-EditIEContextElevationMaxAgeMinutes { return 15 }
function Get-EditIESessionMaxAgeHours { return 8 }

function Test-LaunchContextElevationFreshness {
    param(
        [datetime]$CapturedAt,
        [datetime]$Now,
        [int]$MaxAgeMinutes = (Get-EditIEContextElevationMaxAgeMinutes)
    )
    $age = ($Now - $CapturedAt).TotalMinutes
    return ($age -ge 0 -and $age -le $MaxAgeMinutes)
}

function Test-EditIEMenuSessionFreshness {
    param(
        [datetime]$ValidUntil,
        [datetime]$Now
    )
    return ($ValidUntil -gt $Now)
}

function Test-LaunchContextRunId {
    param([string]$ExpectedRunId, [string]$ActualRunId)
    if ([string]::IsNullOrWhiteSpace($ExpectedRunId)) { return $false }
    return ($ExpectedRunId -eq $ActualRunId)
}

function Test-LauncherTargetSidMatch {
    param([string]$LauncherSid, [string]$TargetUserSid)
    if ([string]::IsNullOrWhiteSpace($LauncherSid) -or [string]::IsNullOrWhiteSpace($TargetUserSid)) { return $false }
    return ($LauncherSid -eq $TargetUserSid)
}

function Get-Tls13SupportAssessment {
    param(
        [int]$OsBuild,
        [bool]$IsWindows11OrLater,
        [bool]$CryptoUiTls13Present,
        [nullable[int]]$SchannelEnabled,
        [nullable[int]]$SchannelDisabledByDefault,
        [bool]$SchannelKeyExists
    )

    $reasons = New-Object System.Collections.Generic.List[string]

    if ($OsBuild -lt 19041) {
        return [pscustomobject]@{
            Status  = 'Unsupported'
            Reasons = @("OS build $OsBuild is below 19041 (TLS 1.3 not in supported Schannel set for this release).")
        }
    }

    if ($SchannelKeyExists -and $null -ne $SchannelEnabled -and $SchannelEnabled -eq 0) {
        return [pscustomobject]@{
            Status  = 'Unsupported'
            Reasons = @('Schannel TLS 1.3 Client has Enabled=0 (explicitly disabled).')
        }
    }

    $schannelExplicitOn = ($SchannelKeyExists -and $null -ne $SchannelEnabled -and $SchannelEnabled -eq 1 -and
        ($null -eq $SchannelDisabledByDefault -or $SchannelDisabledByDefault -eq 0))

    if (-not $IsWindows11OrLater) {
        # Windows client 10: TLS 1.3 is not treated as Supported for SecureProtocols automation
        # (registry/UI presence alone is insufficient per Microsoft Schannel product defaults).
        if (-not $SchannelKeyExists) {
            return [pscustomobject]@{
                Status  = 'Skipped'
                Reasons = @('Windows 10: TLS 1.3 is not auto-enabled in SecureProtocols (no Schannel client key).')
            }
        }
        if ($schannelExplicitOn) {
            return [pscustomobject]@{
                Status  = 'Skipped'
                Reasons = @('Windows 10: Schannel TLS 1.3 may be configured, but Windows 10 is not treated as Supported for automated Advanced alignment.')
            }
        }
        return [pscustomobject]@{
            Status  = 'Skipped'
            Reasons = @('Windows 10: TLS 1.3 Schannel not explicitly enabled (Enabled=1, DisabledByDefault=0).')
        }
    }

    # Windows 11+
    if (-not $SchannelKeyExists) {
        if ($CryptoUiTls13Present) {
            return [pscustomobject]@{
                Status  = 'Supported'
                Reasons = @('Windows 11+: default Schannel TLS 1.3 stack; CRYPTO exposes TLS 1.3 in Advanced.')
            }
        }
        return [pscustomobject]@{
            Status  = 'Skipped'
            Reasons = @('Windows 11+: no Schannel TLS 1.3 key and no CRYPTO TLS 1.3 option — cannot confirm.')
        }
    }

    if ($schannelExplicitOn -or ($null -ne $SchannelDisabledByDefault -and $SchannelDisabledByDefault -eq 0)) {
        return [pscustomobject]@{
            Status  = 'Supported'
            Reasons = @('Windows 11+: Schannel TLS 1.3 client available.')
        }
    }

    if ($CryptoUiTls13Present) {
        return [pscustomobject]@{
            Status  = 'Skipped'
            Reasons = @('Windows 11: TLS 1.3 Schannel default-off; UI present but runtime not confirmed.')
        }
    }

    return [pscustomobject]@{
        Status  = 'Unsupported'
        Reasons = @('Windows 11: TLS 1.3 Schannel default-off and no CRYPTO UI entry.')
    }
}

function Get-SecureProtocolsPolicyPaths {
    param([string]$TargetUserSid)
    $paths = @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings')
    if ($TargetUserSid) {
        $paths += "Registry::HKEY_USERS\$TargetUserSid\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
    }
    return $paths
}

function Get-EditIEExitDecision {
    param(
        [object[]]$Results,
        [switch]$PolicyBlockedSecureProtocols,
        [switch]$LegacyMode,
        [switch]$PartialRestore
    )

    $failed = @($Results | Where-Object { $_.Status -eq 'Failed' })
    if ($failed.Count -gt 0) {
        return [pscustomobject]@{ Code = 2; Message = 'One or more required operations failed.' }
    }

    if ($PartialRestore) {
        return [pscustomobject]@{ Code = 4; Message = 'Partial restore: user settings restored; machine-wide (HKLM) settings were not restored.' }
    }

    $required = @($Results | Where-Object { $_.Required -eq $true })
    $notSuccess = @($required | Where-Object { $_.Status -ne 'Success' })
    if ($notSuccess.Count -gt 0) {
        $blockedOnly = ($notSuccess | Where-Object { $_.Status -ne 'Blocked' }).Count -eq 0
        if ($blockedOnly -and $PolicyBlockedSecureProtocols) {
            return [pscustomobject]@{ Code = 3; Message = 'Partial success: Group Policy blocks SecureProtocols.' }
        }
        return [pscustomobject]@{ Code = 2; Message = 'Required settings were not all applied successfully.' }
    }

    if ($PolicyBlockedSecureProtocols) {
        return [pscustomobject]@{ Code = 3; Message = 'Partial success: Group Policy blocks SecureProtocols.' }
    }

    return [pscustomobject]@{ Code = 0; Message = 'All required settings applied and verified.' }
}

function Test-SecureProtocolsMaskAlignment {
    param([int]$ExpectedMask, [int]$ActualMask)
    return ($ExpectedMask -eq $ActualMask)
}

function Get-CryptoUiTls13Present {
    param([object[]]$CryptoOptions)
    foreach ($opt in $CryptoOptions) {
        $blob = ($opt.Name + ' ' + $opt.Text).ToLowerInvariant()
        if ($blob -match 'tls\s*1\.3|tls1\.3') { return $true }
    }
    return $false
}

function Test-MachineBackupShouldSkipCreate {
    param([bool]$BackupFileExists, [bool]$BackupValid)
    return ($BackupFileExists -and $BackupValid)
}

function Test-SitesXmlBackupImmutable {
    param([bool]$BackupAlreadyExists)
    return $BackupAlreadyExists
}
