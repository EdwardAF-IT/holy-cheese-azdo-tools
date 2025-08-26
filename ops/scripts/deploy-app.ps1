<#
.SYNOPSIS
Deploys the specified version (or current commit) by setting WEBSITE_RUN_FROM_PACKAGE.
Honors staging slot when configured. Performs health check.
#>
param(
  [Parameter(Mandatory)][string] $Env,
  [Parameter()][string] $App = 'azdotools',
  [Parameter()][string] $Version
)
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/_common.ps1"
$cfg  = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yaml")
$envs = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\env-catalog.yaml")
$envCfg = $envs.environments.$Env
if (-not $envCfg) { throw [string]::Format("Unknown env '{0}'", $Env) }

Import-Module $cfg.paths.namingModule -Force
az account set --subscription $cfg.globals.subscriptionId | Out-Null

$org = $cfg.globals.org; $appToken = $cfg.globals.app; $region = $envCfg.regionCode
$rg   = New-ResourceName -Org $org -App $appToken -Env $Env -RegionCode $region -Suffix 'rg'
$fn   = New-ResourceName -Org $org -App $appToken -Env $Env -RegionCode $region -Suffix 'func'
$stg  = New-ResourceName -Org $org -App $appToken -Env $Env -RegionCode $region -Suffix 'stg'

if (-not $Version) {
  $Version = $env:BUILD_SOURCEVERSION
  if (-not $Version) { $Version = (git rev-parse --short HEAD) }
}
$Version = $Version.Substring(0, [Math]::Min(7, $Version.Length))

$container = $cfg.deployment.containerName
$blob = [string]::Format("{0}/{1}/{0}.zip", $App, $Version)

# Generate SAS URL for the blob in the target env's storage
$expiry = (Get-Date).AddHours(2).ToString("yyyy-MM-ddTHH:mmZ")
$sas = az storage blob generate-sas `
  --account-name $stg --container-name $container --name $blob `
  --permissions r --expiry $expiry -o tsv --auth-mode login
$pkgUrl = [string]::Format("https://{0}.blob.core.windows.net/{1}/{2}?{3}", $stg, $container, $blob, $sas)

# Load app deploy defaults (settings)
$deploySpec = Import-YamlSafely -Path ([IO.Path]::Combine('apps', $App, 'app.deploy.yaml'))
$settings = @()
$deploySpec.settings.GetEnumerator() | ForEach-Object { $settings += [string]::Format("{0}={1}", $_.Key, $_.Value) }
$settings += [string]::Format("{0}={1}", 'WEBSITE_RUN_FROM_PACKAGE', $pkgUrl)

# Slot handling from env-catalog
$slot = $envCfg.deploy.slot
if ($slot) {
  az functionapp config appsettings set -g $rg -n $fn --slot $slot --settings $settings | Out-Null
  az webapp deployment slot swap -g $rg -n $fn --slot $slot --target-slot production | Out-Null
} else {
  az functionapp config appsettings set -g $rg -n $fn --settings $settings | Out-Null
}

# Health check
$path = $cfg.deployment.healthCheckPath
if ($path) {
  Start-Sleep -Seconds 10
  $uri = [string]::Format("https://{0}.azurewebsites.net{1}", $fn, $path)
  try {
    Invoke-RestMethod -Uri $uri -TimeoutSec 20 | Out-Null
    Write-Host ([string]::Format("Health check OK: {0}", $uri))
  } catch {
    Write-Warning ([string]::Format("Health check failed: {0}", $uri))
  }
}

Write-Host ([string]::Format("Deployed {0} {1} to {2}", $App, $Version, $Env))
