#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EditIE-Core.ps1')
try {
    $runId = Save-LaunchContext
    # Single line for batch FOR /F capture
    Write-Output $runId
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
