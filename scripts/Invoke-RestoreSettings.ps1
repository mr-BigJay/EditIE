#Requires -Version 5.1
param([string]$RunId)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EditIE-Core.ps1')

Initialize-EditIELogging -OperationName 'Restore'
$results = New-Object System.Collections.Generic.List[object]

try {
    $userCtx = Get-TargetUserContext -RunId $RunId
    $mount = Get-UserRegistryMount -UserSid $userCtx.UserSid

    foreach ($r in (Restore-UserSettingsFromBackup -UserSid $userCtx.UserSid -UserHivePrefix $mount.HivePrefix)) {
        $results.Add($r) | Out-Null
    }
    foreach ($r in (Restore-MachineSettingsFromBackup -RequestingUserSid $userCtx.UserSid -UserHivePrefix $mount.HivePrefix)) {
        $results.Add($r) | Out-Null
    }

    $failed = @($results | Where-Object { $_.Status -eq 'Failed' })
    $skipped = @($results | Where-Object { $_.Status -eq 'Skipped' })

    Show-EditIESummary -Results $results -Notes @(
        "Restore failures: $($failed.Count); skipped: $($skipped.Count)."
        'User HKU settings always restored; HKLM only when machine backup owner SID matches.'
        'Reopen inetcpl.cpl and restart Edge to verify.'
    )

    if ($failed.Count -gt 0) {
        Write-Host 'Restore completed with errors (partial restore).'
        exit 2
    }
    Write-Host 'Restore completed.'
    exit 0
}
catch {
    Write-EditIELog $_.Exception.Message 'ERROR'
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}
