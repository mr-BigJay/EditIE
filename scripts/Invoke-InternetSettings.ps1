#Requires -Version 5.1
param(
    [ValidateSet('Modern', 'Legacy')][string]$TlsMode = 'Modern',
    [string]$RunId
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EditIE-Core.ps1')

Initialize-EditIELogging -OperationName "Internet_$TlsMode"
$results = New-Object System.Collections.Generic.List[object]
$notes = New-Object System.Collections.Generic.List[string]
$policyBlocked = $false

try {
    $userCtx = Get-TargetUserContext -RunId $RunId
    Write-EditIELog "Target user: $($userCtx.UserName) ($($userCtx.UserSid)) Source=$($userCtx.Source)" 'INFO'
    Write-EditIELog "Process identity: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" 'INFO'

    $mount = Get-UserRegistryMount -UserSid $userCtx.UserSid
    $userHive = $mount.HivePrefix
    Initialize-SettingsBackup -UserSid $userCtx.UserSid -UserHivePrefix $userHive | Out-Null

    $legacy = ($TlsMode -eq 'Legacy')
    if ($legacy) {
        Write-Host ''
        Write-Host 'WARNING: Legacy TLS enables SSL 3.0 / TLS 1.0 / TLS 1.1 (insecure).'
        Write-Host ''
    }

    $trustedBase = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir'
    foreach ($sub in @('at', 'oa1', 'oa2', 'oa3', 'oa4')) {
        foreach ($proto in @('http', 'https')) {
            $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix $userHive -SubKey "$trustedBase\$sub" -Name $proto -Data '2' -SettingLabel "Trusted site $sub ($proto)" -Required $true -Category 'User')) | Out-Null
        }
    }

    $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix $userHive -SubKey 'Software\Microsoft\Internet Explorer\New Windows' -Name 'PopupMgr' -Data '0' -SettingLabel 'Popup blocker' -Required $true -Category 'User')) | Out-Null

    $policyBlocks = Get-SecureProtocolsPolicyBlock -TargetUserSid $userCtx.UserSid
    if ($policyBlocks.Count -gt 0) {
        $policyBlocked = $true
        foreach ($b in $policyBlocks) {
            $msg = "SecureProtocols managed by Group Policy at $($b.Path) = $($b.Value) (0x$('{0:X}' -f $b.Value))"
            Write-EditIELog $msg 'BLOCKED'
            $results.Add((New-EditIEResult -Label 'SecureProtocols (Internet Options Advanced)' -Status 'Blocked' -Detail $msg -Required $true -Category 'Policy')) | Out-Null
        }
        $notes.Add('SecureProtocols is locked by Group Policy for the target user or machine.') | Out-Null
    }
    else {
        $maskInfo = Get-SecureProtocolsMask -LegacyTls:$legacy
        Write-EditIELog ("SecureProtocols mask: {0} ({1}) => {2}" -f $maskInfo.Hex, $maskInfo.Value, ($maskInfo.Protocols -join ', ')) 'INFO'

        $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix $userHive -SubKey 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name 'SecureProtocols' -Data ([string]$maskInfo.Value) -SettingLabel 'SecureProtocols (Internet Options Advanced)' -Required $true -Category 'User')) | Out-Null
        $results.Add((Confirm-SecureProtocolsForUser -UserHivePrefix $userHive -ExpectedMask $maskInfo.Value)) | Out-Null

        foreach ($winHttpPath in @(
                'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
                'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
            )) {
            $label = "WinHTTP DefaultSecureProtocols ($winHttpPath)"
            $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey $winHttpPath -Name 'DefaultSecureProtocols' -Data ([string]$maskInfo.Value) -SettingLabel $label -Required $true -Category 'WinHTTP')) | Out-Null
        }
        $notes.Add('WinHTTP is separate from Internet Options Advanced; restart WinHTTP clients if needed.') | Out-Null
    }

    if ($legacy) {
        foreach ($r in Set-SchannelLegacyClientProtocols) { $results.Add($r) | Out-Null }
        $notes.Add('Legacy Schannel changes may require a reboot.') | Out-Null
    }

    $results.Add((New-EditIEResult -Label 'WinTrust Software Publishing State' -Status 'Skipped' -Detail 'Not modified (revocation defaults preserved)' -Required $false)) | Out-Null

    Show-EditIESummary -Results $results -Notes $notes

    $decision = Get-EditIEExitDecision -Results $results -PolicyBlockedSecureProtocols:$policyBlocked -LegacyMode:$legacy
    Write-Host ''
    Write-Host $decision.Message
    if ($decision.Code -eq 0) {
        Write-Host 'Reopen inetcpl.cpl (Advanced) and confirm TLS checkboxes match the log mask.'
    }
    exit $decision.Code
}
catch {
    Write-EditIELog $_.Exception.Message 'ERROR'
    Write-Host "Error: $($_.Exception.Message)"
    if ($script:LogFilePath) { Write-Host "Log: $script:LogFilePath" }
    exit 1
}
