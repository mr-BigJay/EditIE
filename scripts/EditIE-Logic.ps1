#Requires -Version 5.1
# Pure logic helpers (no registry I/O) — unit-testable on non-Windows hosts.
Set-StrictMode -Version Latest

$script:SecureProtocolBits = @{
    Ssl3Client  = 0x00000020
    Tls10Client = 0x00000080
    Tls11Client = 0x00000200
    Tls12Client = 0x00000800
    Tls13Client = 0x00002000
}

function Get-EditIEContextMaxAgeMinutes { return 15 }

function Test-LaunchContextFreshness {
    param(
        [datetime]$CapturedAt,
        [datetime]$Now,
        [int]$MaxAgeMinutes = (Get-EditIEContextMaxAgeMinutes)
    )
    $age = ($Now - $CapturedAt).TotalMinutes
    return ($age -ge 0 -and $age -le $MaxAgeMinutes)
}

function Test-LaunchContextRunId {
    param(
        [string]$ExpectedRunId,
        [string]$ActualRunId
    )
    if ([string]::IsNullOrWhiteSpace($ExpectedRunId)) { return $false }
    return ($ExpectedRunId -eq $ActualRunId)
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
    $status = 'Skipped'

    if ($OsBuild -lt 19041) {
        return [pscustomobject]@{
            Status  = 'Unsupported'
            Reasons = @("OS build $OsBuild is below 19041 (TLS 1.3 not available on this Windows release).")
        }
    }

    if ($SchannelKeyExists -and $null -ne $SchannelEnabled -and $SchannelEnabled -eq 0) {
        return [pscustomobject]@{
            Status  = 'Unsupported'
            Reasons = @('Schannel TLS 1.3 Client has Enabled=0 (explicitly disabled).')
        }
    }

    $schannelDefaultOff = ($SchannelKeyExists -and $null -ne $SchannelDisabledByDefault -and $SchannelDisabledByDefault -eq 1 -and
        ($null -eq $SchannelEnabled -or $SchannelEnabled -ne 1))

    if ($IsWindows11OrLater) {
        if (-not $SchannelKeyExists) {
            if ($CryptoUiTls13Present) {
                $status = 'Supported'
                $reasons.Add('Windows 11+: no explicit Schannel TLS 1.3 key, but Internet Options CRYPTO exposes TLS 1.3.') | Out-Null
            }
            else {
                $status = 'Skipped'
                $reasons.Add('Windows 11+: Schannel TLS 1.3 key absent and no TLS 1.3 Advanced option in CRYPTO — cannot confirm.') | Out-Null
            }
        }
        elseif ($schannelDefaultOff) {
            if ($CryptoUiTls13Present) {
                $status = 'Skipped'
                $reasons.Add('Windows 11: TLS 1.3 Schannel default-off without Enabled=1; UI present but runtime uncertain.') | Out-Null
            }
            else {
                $status = 'Unsupported'
                $reasons.Add('Windows 11: TLS 1.3 Schannel default-off and no CRYPTO UI entry.') | Out-Null
            }
        }
        else {
            $status = 'Supported'
            $reasons.Add('Windows 11: Schannel TLS 1.3 client configuration allows use.') | Out-Null
        }
    }
    else {
        # Windows 10 — presence of registry key alone is insufficient
        if (-not $SchannelKeyExists) {
            $status = 'Skipped'
            $reasons.Add('Windows 10: no Schannel TLS 1.3 Client key — not treating as supported.') | Out-Null
        }
        elseif ($schannelDefaultOff) {
            $status = 'Skipped'
            $reasons.Add('Windows 10: TLS 1.3 Schannel present but default-disabled without Enabled=1.') | Out-Null
        }
        elseif ($CryptoUiTls13Present) {
            $status = 'Supported'
            $reasons.Add('Windows 10: TLS 1.3 Schannel enabled and CRYPTO UI includes TLS 1.3.') | Out-Null
        }
        else {
            $status = 'Skipped'
            $reasons.Add('Windows 10: Schannel allows TLS 1.3 but CRYPTO UI entry missing — uncertain Advanced alignment.') | Out-Null
        }
    }

    return [pscustomobject]@{
        Status  = $status
        Reasons = [string[]]$reasons
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
        [switch]$LegacyMode
    )

    $failed = @($Results | Where-Object { $_.Status -eq 'Failed' })
    if ($failed.Count -gt 0) {
        return [pscustomobject]@{ Code = 2; Message = 'One or more required operations failed.' }
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
    param(
        [int]$ExpectedMask,
        [int]$ActualMask
    )
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
