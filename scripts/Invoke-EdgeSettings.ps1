#Requires -Version 5.1
param([string]$RunId)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EditIE-Core.ps1')

Initialize-EditIELogging -OperationName 'Edge'
$results = New-Object System.Collections.Generic.List[object]

try {
    $userCtx = Get-TargetUserContext -RunId $RunId
    $mount = Get-UserRegistryMount -UserSid $userCtx.UserSid
    Initialize-SettingsBackup -UserSid $userCtx.UserSid -UserHivePrefix $mount.HivePrefix | Out-Null

    if (-not (Test-Path $script:EditIEDataRoot)) { New-Item -ItemType Directory -Path $script:EditIEDataRoot -Force | Out-Null }

    @'
<?xml version="1.0" encoding="utf-8"?>
<site-list version="1">
<site url="http://at.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
<site url="https://at.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
<site url="http://oa1.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
<site url="http://oa2.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
<site url="http://oa3.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
<site url="http://oa4.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
<site url="https://oa1.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
<site url="https://oa2.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
<site url="https://oa3.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
<site url="https://oa4.gums.ac.ir/"><compat-mode>IE11</compat-mode><open-in>IE11</open-in></site>
</site-list>
'@ | Set-Content -Path $script:EditIESitesXml -Encoding UTF8

    $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey 'SOFTWARE\Policies\Microsoft\Edge' -Name 'InternetExplorerIntegrationLevel' -Data '1' -SettingLabel 'Edge IE integration level' -Required $true -Category 'Machine')) | Out-Null
    $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey 'SOFTWARE\Policies\Microsoft\Edge' -Name 'InternetExplorerIntegrationSiteList' -Type 'REG_SZ' -Data $script:EditIESitesXml -SettingLabel 'Edge IE site list' -Required $true -Category 'Machine')) | Out-Null

    Start-Process -FilePath 'taskkill' -ArgumentList '/F', '/IM', 'msedge.exe' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null

    $decision = Get-EditIEExitDecision -Results $results
    Show-EditIESummary -Results $results -Notes @('Restart Microsoft Edge if it was open.')
    Write-Host $decision.Message
    exit $decision.Code
}
catch {
    Write-EditIELog $_.Exception.Message 'ERROR'
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}
