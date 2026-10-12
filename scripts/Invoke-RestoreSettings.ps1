#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EditIE-Core.ps1')

Initialize-EditIELogging -OperationName 'Restore'
$results = New-Object System.Collections.Generic.List[object]

try {
    $userCtx = Get-TargetUserContext
    Write-EditIELog "Target user: $($userCtx.UserName) ($($userCtx.UserSid))" 'INFO'

    $mount = Get-UserRegistryMount -UserSid $userCtx.UserSid
    $restored = Restore-SettingsFromBackup -UserSid $userCtx.UserSid -UserHivePrefix $mount.HivePrefix
    foreach ($r in $restored) { $results.Add($r) | Out-Null }

    $failed = @($results | Where-Object { $_.Status -eq 'Failed' })
    Show-EditIESummary -Results $results -Notes @(
        'Settings were restored from the backup captured before the first configuration change.'
        'Restart Microsoft Edge and reopen Internet Options to verify.'
        'Reboot if Schannel values were previously changed in Legacy mode.'
    )

    if ($failed.Count -gt 0) {
        Write-Host ''
        Write-Host 'Restore completed with errors. See log.'
        exit 2
    }

    Write-Host ''
    Write-Host 'Settings restored from backup successfully.'
    exit 0
}
catch {
    Write-EditIELog $_.Exception.Message 'ERROR'
    Write-Host ''
    Write-Host "Error: $($_.Exception.Message)"
    if ($script:LogFilePath) { Write-Host "Log: $script:LogFilePath" }
    exit 1
}
