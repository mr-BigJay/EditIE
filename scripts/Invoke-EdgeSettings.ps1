#Requires -Version 5.1
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EditIE-Core.ps1')

Initialize-EditIELogging -OperationName 'Edge'
$results = New-Object System.Collections.Generic.List[object]

try {
    $userCtx = Get-TargetUserContext
    Write-EditIELog "Target user: $($userCtx.UserName) ($($userCtx.UserSid))" 'INFO'

    $mount = Get-UserRegistryMount -UserSid $userCtx.UserSid
    $null = Initialize-SettingsBackup -UserSid $userCtx.UserSid -UserHivePrefix $mount.HivePrefix

    if (-not (Test-Path $script:EditIEDataRoot)) {
        New-Item -ItemType Directory -Path $script:EditIEDataRoot -Force | Out-Null
    }

    $sitesXml = Join-Path $script:EditIEDataRoot 'sites.xml'
    @'
<?xml version="1.0" encoding="utf-8"?>
<site-list version="1">
<site url="http://at.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
<site url="https://at.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
<site url="http://oa1.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
<site url="http://oa2.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
<site url="http://oa3.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
<site url="http://oa4.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
<site url="https://oa1.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
<site url="https://oa2.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
<site url="https://oa3.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
<site url="https://oa4.gums.ac.ir/">
<compat-mode>IE11</compat-mode>
<open-in>IE11</open-in>
</site>
</site-list>
'@ | Set-Content -Path $sitesXml -Encoding UTF8

    $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey 'SOFTWARE\Policies\Microsoft\Edge' -Name 'InternetExplorerIntegrationLevel' -Data '1' -SettingLabel 'Edge IE integration level')) | Out-Null
    $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey 'SOFTWARE\Policies\Microsoft\Edge' -Name 'InternetExplorerIntegrationSiteList' -Type 'REG_SZ' -Data $sitesXml -SettingLabel 'Edge IE site list')) | Out-Null

    $kill = Start-Process -FilePath 'taskkill' -ArgumentList '/F', '/IM', 'msedge.exe' -Wait -PassThru -WindowStyle Hidden
    if ($kill.ExitCode -gt 1) {
        Write-EditIELog 'Microsoft Edge was not running (taskkill skipped)' 'SKIP'
    }
    else {
        Write-EditIELog 'Microsoft Edge processes terminated for policy refresh' 'INFO'
    }

    $failed = @($results | Where-Object { $_.Status -eq 'Failed' })
    if ($failed.Count -gt 0) {
        Write-Host ''
        Write-Host 'Edge settings completed with errors. See log for details.'
        exit 2
    }

    Write-Host ''
    Write-Host 'Microsoft Edge settings applied successfully.'
    Show-EditIESummary -Results $results -Notes @('Restart Microsoft Edge if it was open during configuration.')
    exit 0
}
catch {
    Write-EditIELog $_.Exception.Message 'ERROR'
    Write-Host ''
    Write-Host "Error: $($_.Exception.Message)"
    if ($script:LogFilePath) { Write-Host "Log: $script:LogFilePath" }
    exit 1
}
