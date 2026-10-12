#Requires -Version 5.1
param(
    [ValidateSet('Modern', 'Legacy')]
    [string]$TlsMode = 'Modern'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EditIE-Core.ps1')

Initialize-EditIELogging -OperationName "Internet_$TlsMode"
$results = New-Object System.Collections.Generic.List[object]
$notes = New-Object System.Collections.Generic.List[string]

try {
    $userCtx = Get-TargetUserContext
    Write-EditIELog "Target user: $($userCtx.UserName) ($($userCtx.UserSid)) Source=$($userCtx.Source)" 'INFO'
    Write-EditIELog "Process identity: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" 'INFO'

    $mount = Get-UserRegistryMount -UserSid $userCtx.UserSid
    $userHive = $mount.HivePrefix
    $null = Initialize-SettingsBackup -UserSid $userCtx.UserSid -UserHivePrefix $userHive

    $legacy = ($TlsMode -eq 'Legacy')
    if ($legacy) {
        Write-Host ''
        Write-Host 'WARNING: Legacy TLS enables SSL 3.0 / TLS 1.0 / TLS 1.1 (insecure). Use only if required by older GUMS systems.'
        Write-Host ''
    }

    $trustedBase = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\gums.ac.ir'
    foreach ($sub in @('at', 'oa1', 'oa2', 'oa3', 'oa4')) {
        foreach ($proto in @('http', 'https')) {
            $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix $userHive -SubKey "$trustedBase\$sub" -Name $proto -Data '2' -SettingLabel "Trusted site $sub ($proto)")) | Out-Null
        }
    }

    $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix $userHive -SubKey 'Software\Microsoft\Internet Explorer\New Windows' -Name 'PopupMgr' -Data '0' -SettingLabel 'Popup blocker')) | Out-Null

    $policyBlocks = Get-SecureProtocolsPolicyBlock
    if ($policyBlocks.Count -gt 0) {
        foreach ($b in $policyBlocks) {
            $msg = "SecureProtocols is managed by Group Policy at $($b.Path) = $($b.Value) (0x$('{0:X}' -f $b.Value))"
            Write-EditIELog $msg 'BLOCKED'
            $results.Add([pscustomobject]@{
                    Label  = 'SecureProtocols (Internet Options Advanced)'
                    Status = 'Blocked'
                    Detail = $msg
                }) | Out-Null
        }
        $notes.Add('SecureProtocols is locked by Group Policy — Advanced TLS checkboxes cannot be changed locally.') | Out-Null
    }
    else {
        $maskInfo = Get-SecureProtocolsMask -LegacyTls:$legacy
        Write-EditIELog ("SecureProtocols mask: {0} ({1}) => {2}" -f $maskInfo.Hex, $maskInfo.Value, ($maskInfo.Protocols -join ', ')) 'INFO'

        $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix $userHive -SubKey 'Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name 'SecureProtocols' -Data ([string]$maskInfo.Value) -SettingLabel 'SecureProtocols (Internet Options Advanced)')) | Out-Null

        foreach ($winHttpPath in @(
                'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
                'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
            )) {
            $label = "WinHTTP DefaultSecureProtocols ($winHttpPath)"
            $results.Add((Invoke-EditIERegistry -Operation Add -HivePrefix 'HKLM:' -SubKey $winHttpPath -Name 'DefaultSecureProtocols' -Data ([string]$maskInfo.Value) -SettingLabel $label)) | Out-Null
        }
        $notes.Add('WinHTTP DefaultSecureProtocols was updated separately from Internet Options (Advanced); restart apps using WinHTTP if TLS behavior does not change.') | Out-Null
    }

    if ($legacy) {
        Write-EditIELog 'Applying Schannel legacy client protocol keys (Legacy mode only)' 'WARN'
        foreach ($r in Set-SchannelLegacyClientProtocols -Enable) {
            $results.Add($r) | Out-Null
        }
        $notes.Add('Legacy Schannel client keys were updated; a reboot may be required for all applications to negotiate legacy TLS.') | Out-Null
    }
    else {
        Write-EditIELog 'Skipping Schannel protocol changes (Modern mode)' 'SKIP'
        $results.Add([pscustomobject]@{
                Label  = 'Schannel protocols'
                Status = 'Skipped'
                Detail = 'Modern mode does not modify Schannel (OS defaults retained)'
            }) | Out-Null
    }

    Write-EditIELog 'Certificate revocation (WinTrust) left unchanged — default OS/user revocation settings preserved' 'INFO'
    $results.Add([pscustomobject]@{
            Label  = 'WinTrust Software Publishing State'
            Status = 'Skipped'
            Detail = 'Not modified (revocation checks not disabled globally)'
        }) | Out-Null

    $requiredOk = @(
        ($results | Where-Object { $_.Label -like 'Trusted site*' -and $_.Status -eq 'Failed' }).Count -eq 0
        ($results | Where-Object { $_.Label -eq 'Popup blocker' -and $_.Status -eq 'Failed' }).Count -eq 0
    )

    $secure = $results | Where-Object { $_.Label -like 'SecureProtocols*' } | Select-Object -First 1
    $secureOk = ($null -eq $secure) -or ($secure.Status -in @('Success', 'Blocked'))

    Show-EditIESummary -Results $results -Notes $notes

    if (-not ($requiredOk[0] -and $requiredOk[1] -and $secureOk)) {
        Write-Host ''
        Write-Host 'Internet Options settings completed with errors. Required items were not all applied.'
        Write-Host 'Close and reopen inetcpl.cpl (Internet Options) to refresh the Advanced tab.'
        exit 2
    }

    if ($policyBlocks.Count -gt 0) {
        Write-Host ''
        Write-Host 'Partial success: trusted sites and popup settings were applied, but TLS checkboxes are controlled by Group Policy.'
        exit 3
    }

    Write-Host ''
    Write-Host 'Internet Options settings applied successfully.'
    Write-Host 'Close and reopen Internet Options (inetcpl.cpl) or sign out/in if Advanced checkboxes still look stale.'
    exit 0
}
catch {
    Write-EditIELog $_.Exception.Message 'ERROR'
    Write-Host ''
    Write-Host "Error: $($_.Exception.Message)"
    if ($script:LogFilePath) { Write-Host "Log: $script:LogFilePath" }
    exit 1
}
