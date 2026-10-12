#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts\EditIE-Logic.ps1')

$failures = 0
function Assert-True($cond, [string]$name) {
    if (-not $cond) { Write-Host "FAIL: $name"; $script:failures++ }
    else { Write-Host "OK: $name" }
}

# TLS 1.3 — Windows 10 old key default-off
$a = Get-Tls13SupportAssessment -OsBuild 19045 -IsWindows11OrLater $false -CryptoUiTls13Present $true `
    -SchannelEnabled $null -SchannelDisabledByDefault 1 -SchannelKeyExists $true
Assert-True ($a.Status -eq 'Skipped') 'Win10 TLS1.3 key default-off without Enabled=1 => Skipped'

# Windows 11 without Schannel key but CRYPTO UI
$a = Get-Tls13SupportAssessment -OsBuild 22631 -IsWindows11OrLater $true -CryptoUiTls13Present $true `
    -SchannelEnabled $null -SchannelDisabledByDefault $null -SchannelKeyExists $false
Assert-True ($a.Status -eq 'Supported') 'Win11 no Schannel key + CRYPTO TLS1.3 => Supported'

# Windows 11 without key and without UI
$a = Get-Tls13SupportAssessment -OsBuild 22631 -IsWindows11OrLater $true -CryptoUiTls13Present $false `
    -SchannelEnabled $null -SchannelDisabledByDefault $null -SchannelKeyExists $false
Assert-True ($a.Status -eq 'Skipped') 'Win11 no key no UI => Skipped'

# Explicit disable
$a = Get-Tls13SupportAssessment -OsBuild 22631 -IsWindows11OrLater $true -CryptoUiTls13Present $true `
    -SchannelEnabled 0 -SchannelDisabledByDefault 1 -SchannelKeyExists $true
Assert-True ($a.Status -eq 'Unsupported') 'Enabled=0 => Unsupported'

# Launch context freshness
Assert-True (Test-LaunchContextFreshness -CapturedAt (Get-Date).AddMinutes(-5) -Now (Get-Date)) 'Context 5 min old valid'
Assert-True (-not (Test-LaunchContextFreshness -CapturedAt (Get-Date).AddMinutes(-20) -Now (Get-Date))) 'Context 20 min old invalid'

# Exit code — WinHTTP failure
$results = @(
    [pscustomobject]@{ Label = 'Trusted site'; Status = 'Success'; Required = $true }
    [pscustomobject]@{ Label = 'WinHTTP x64'; Status = 'Failed'; Required = $true }
)
$d = Get-EditIEExitDecision -Results $results
Assert-True ($d.Code -eq 2) 'WinHTTP Failed => exit 2'

# Exit code — GPO blocked only
$results = @(
    [pscustomobject]@{ Label = 'Trusted'; Status = 'Success'; Required = $true }
    [pscustomobject]@{ Label = 'SecureProtocols'; Status = 'Blocked'; Required = $true }
)
$d = Get-EditIEExitDecision -Results $results -PolicyBlockedSecureProtocols
Assert-True ($d.Code -eq 3) 'Policy blocked SecureProtocols => exit 3'

# Schannel legacy failure
$results = @(
    [pscustomobject]@{ Label = 'Schannel TLS 1.0'; Status = 'Failed'; Required = $true }
)
$d = Get-EditIEExitDecision -Results $results -LegacyMode
Assert-True ($d.Code -eq 2) 'Schannel Failed legacy => exit 2'

# Policy paths include HKU SID
$paths = Get-SecureProtocolsPolicyPaths -TargetUserSid 'S-1-5-21-test'
Assert-True ($paths.Count -ge 2) 'Policy paths HKLM + HKU'
Assert-True ($paths[1] -like '*S-1-5-21-test*') 'HKU path uses target SID'

# Mask alignment
Assert-True (Test-SecureProtocolsMaskAlignment -ExpectedMask 0x2800 -ActualMask 0x2800) 'Mask alignment equal'

if ($failures -gt 0) {
    Write-Host "`n$failures test(s) failed."
    exit 1
}
Write-Host "`nAll logic tests passed."
exit 0
