#Requires -Version 5.1
param([Parameter(Mandatory)][string]$RunId)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EditIE-Core.ps1')
Register-EditIEMenuSession -RunId $RunId
