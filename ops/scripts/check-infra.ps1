<#
.SYNOPSIS
Validates infra readiness for a given environment. If this fails, deployment will not proceed.
#>
param(
  [Parameter(Mandatory)][string] $Env
)
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/_common.ps1"
$cfg  = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yml")
$envs = Import-YamlSafely -Path $cfg.paths.envCatalog
$envCfg = $envs.environments.$Env
if (-not $envCfg) { throw [string]::Format("Unknown env '{0}'", $Env) }

# Import naming
Import-Module $cfg.paths.namingModule -Force

# Subscription
az account set --subscription $cfg.globals.subscriptionId | Out-Null

# Compute names
$org = $cfg.globals.org
$app = $cfg.globals.app
$region = $envCfg.regionCode
$rg  = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'rg'
$fn  = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'func'

# Check RG and readiness tag
$rgObj = az group show -n $rg -o json | ConvertFrom-Json
if (-not $rgObj) { throw [string]::Format("Resource group '{0}' missing", $rg) }
if ($rgObj.tags.'org:infraReady' -ne 'true') { throw [string]::Format("Infra not ready in '{0}'", $rg) }

# Check Function App existence
$func = az functionapp show -g $rg -n $fn -o json | ConvertFrom-Json
if (-not $func) { throw [string]::Format("Function App '{0}' missing", $fn) }

Write-Host ([string]::Format("Infra ready for env '{0}'", $Env))
