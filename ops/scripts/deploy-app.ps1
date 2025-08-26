<#
.SYNOPSIS
Deploys the specified version of the app to the target environment.
If -Version is 'auto' or omitted, resolves the latest published version from blob storage.
#>

param(
  [Parameter(Mandatory)][string] $Env,
  [Parameter()][string] $App = 'azdotools',
  [Parameter()][string] $Version = 'auto'
)

$ErrorActionPreference = 'Stop'

# Load shared config and helpers
. "$PSScriptRoot/_common.ps1"
$cfg     = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yml")
$envs    = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\env-catalog.yml")
$envCfg  = $envs.environments.$Env
if (-not $envCfg) { throw "Unknown environment '$Env'" }

Import-Module $cfg.paths.namingModule -Force
az account set --subscription $cfg.globals.subscriptionId | Out-Null

# Compute resource names
$org    = $cfg.globals.org
$appKey = $cfg.globals.app
$region = $envCfg.regionCode
$rg     = New-ResourceName -Org $org -App $appKey -Env $Env -RegionCode $region -Suffix 'rg'
$fn     = New-ResourceName -Org $org -App $appKey -Env $Env -RegionCode $region -Suffix 'func'
$stg    = New-ResourceName -Org $org -App $appKey -Env $Env -RegionCode $region -Suffix 'stg'

# Resolve version if 'auto'
if ($Version -eq 'auto' -or [string]::IsNullOrWhiteSpace($Version)) {
  $container = $cfg.deployment.containerName
  $prefix    = [string]::Format("{0}/", $App)
  $blobs     = az storage blob list `
    --account-name $stg `
    --container-name $container `
    --prefix $prefix `
    --query "[].name" -o tsv `
    --auth-mode login

  $versions = $blobs | Where-Object { $_ -match "$App\.zip$" } |
    ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Descending

  if (-not $versions) {
    throw "No published versions found for app '$App' in env '$Env'"
  }

  $Version = $versions[0]
  Write-Host "Auto-selected latest version: $Version"
}

# Construct SAS URL for the package
$container = $cfg.deployment.containerName
$blob      = [string]::Format("{0}/{1}/{0}.zip", $App, $Version)
$expiry    = (Get-Date).AddHours(2).ToString("yyyy-MM-ddTHH:mmZ")
$sas       = az storage blob generate-sas `
  --account-name $stg `
  --container-name $container `
  --name $blob `
  --permissions r `
  --expiry $expiry `
  -o tsv `
  --auth-mode login

$pkgUrl = [string]::Format("https://{0}.blob.core.windows.net/{1}/{2}?{3}", $stg, $container, $blob, $sas)

# Load app settings from deploy spec
$deploySpec = Import-YamlSafely -Path ([IO.Path]::Combine('apps', $App, 'app.deploy.yaml'))
$settings   = @()
$deploySpec.settings.GetEnumerator() | ForEach-Object {
  $settings += [string]::Format("{0}={1}", $_.Key, $_.Value)
}
$settings += [string]::Format("WEBSITE_RUN_FROM_PACKAGE={0}", $pkgUrl)

# Deploy to slot if configured
$slot = $envCfg.deploy.slot
if ($slot) {
  az functionapp config appsettings set -g $rg -n $fn --slot $slot --settings $settings | Out-Null
  az webapp deployment slot swap -g $rg -n $fn --slot $slot --target-slot production | Out-Null
  Write-Host "Deployed to slot '$slot' and swapped to production"
} else {
  az functionapp config appsettings set -g $rg -n $fn --settings $settings | Out-Null
  Write-Host "Deployed directly to production"
}

# Health check
$path = $cfg.deployment.healthCheckPath
if ($path) {
  Start-Sleep -Seconds 10
  $uri = [string]::Format("https://{0}.azurewebsites.net{1}", $fn, $path)
  try {
    Invoke-RestMethod -Uri $uri -TimeoutSec 20 | Out-Null
    Write-Host "Health check passed: $uri"
  } catch {
    Write-Warning "Health check failed: $uri"
  }
}

Write-Host ([string]::Format("Deployment complete: {0} {1} → {2}", $App, $Version, $Env))
