#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts\EditIE-Logic.ps1')

$failures = 0
function Assert-True($cond, [string]$name) {
    if (-not $cond) { Write-Host "FAIL: $name"; $script:failures++ }
    else { Write-Host "OK: $name" }
}

# Win10 never Supported (even explicit Schannel + CRYPTO)
$a = Get-Tls13SupportAssessment -OsBuild 19045 -IsWindows11OrLater $false -CryptoUiTls13Present $true `
    -SchannelEnabled 1 -SchannelDisabledByDefault 0 -SchannelKeyExists $true
Assert-True ($a.Status -eq 'Skipped') 'Win10 explicit Schannel + CRYPTO => Skipped not Supported'

$a = Get-Tls13SupportAssessment -OsBuild 19045 -IsWindows11OrLater $false -CryptoUiTls13Present $true `
    -SchannelEnabled $null -SchannelDisabledByDefault 1 -SchannelKeyExists $true
Assert-True ($a.Status -eq 'Skipped') 'Win10 TLS1.3 key default-off => Skipped'

$a = Get-Tls13SupportAssessment -OsBuild 22631 -IsWindows11OrLater $true -CryptoUiTls13Present $true `
    -SchannelEnabled $null -SchannelDisabledByDefault $null -SchannelKeyExists $false
Assert-True ($a.Status -eq 'Supported') 'Win11 no Schannel key + CRYPTO => Supported'

Assert-True (Test-LauncherTargetSidMatch -LauncherSid 'S-1-1' -TargetUserSid 'S-1-1') 'Launcher/target SID match'
Assert-True (-not (Test-LauncherTargetSidMatch -LauncherSid 'S-1-1' -TargetUserSid 'S-1-2')) 'RDP SID mismatch detected'

Assert-True (Test-MachineBackupShouldSkipCreate -BackupFileExists $true -BackupValid $true) 'Machine backup not overwritten'
Assert-True (Test-SitesXmlBackupImmutable -BackupAlreadyExists $true) 'sites.xml.bak not overwritten'

Assert-True (Test-LaunchContextElevationFreshness -CapturedAt (Get-Date).AddMinutes(-5) -Now (Get-Date)) 'Elevation window 5m'
Assert-True (Test-EditIEMenuSessionFreshness -ValidUntil (Get-Date).AddHours(2) -Now (Get-Date)) 'Menu session 2h'

$d = Get-EditIEExitDecision -Results @() -PartialRestore
Assert-True ($d.Code -eq 4) 'Partial restore exit 4'

$d = Get-EditIEExitDecision -Results @(
    [pscustomobject]@{ Status = 'Success'; Required = $true }
    [pscustomobject]@{ Status = 'Failed'; Required = $true }
)
Assert-True ($d.Code -eq 2) 'Failed required => exit 2'

if ($failures -gt 0) {
    Write-Host "`n$failures test(s) failed."
    exit 1
}
Write-Host "`nAll logic tests passed."
exit 0
