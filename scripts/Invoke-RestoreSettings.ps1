#Requires -Version 5.1
param([string]$RunId)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EditIE-Core.ps1')

Initialize-EditIELogging -OperationName 'Restore'
$results = New-Object System.Collections.Generic.List[object]
$partial = $false

try {
    $userCtx = Get-TargetUserContext -RunId $RunId
    $mount = Get-UserRegistryMount -UserSid $userCtx.UserSid

    $partialRef = [ref]$partial
    foreach ($r in (Restore-SettingsFromBackup -UserSid $userCtx.UserSid -UserHivePrefix $mount.HivePrefix -PartialRestore $partialRef)) {
        $results.Add($r) | Out-Null
    }

    $failed = @($results | Where-Object { $_.Status -eq 'Failed' })
    Show-EditIESummary -Results $results -Notes @(
        "Partial restore (HKLM skipped): $partial"
        'User HKU settings restored from backup_user_<Sid>.json when available.'
    )

    if ($failed.Count -gt 0) {
        Write-Host 'Restore completed with errors.'
        exit 2
    }

    $decision = Get-EditIEExitDecision -Results $results -PartialRestore:$partial
    Write-Host $decision.Message
    exit $decision.Code
}
catch {
    Write-EditIELog $_.Exception.Message 'ERROR'
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}
