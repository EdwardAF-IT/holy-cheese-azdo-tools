<#
.SYNOPSIS
Uploads the same app package to each target env's storage (no inter-stage state).
#>
param(
  [Parameter(Mandatory)][string[]] $Envs,
  [Parameter()][string] $App = 'azdotools'
)
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/_common.ps1"
$cfg  = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yml")
$envs = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\env-catalog.yml")
Import-Module $cfg.paths.namingModule -Force

# Select subscription once
az account set --subscription $cfg.globals.subscriptionId | Out-Null

# Version for addressing the blob (short SHA for determinism)
$version = $env:BUILD_SOURCEVERSION
if (-not $version) {
  $version = (git rev-parse --short HEAD)
}
$version = $version.Substring(0, [Math]::Min(7, $version.Length))

$pkg = $cfg.paths.packagePath
if (-not (Test-Path $pkg)) { throw [string]::Format("Package not found at {0}. Run build-app.ps1 first.", $pkg) }

$container = $cfg.deployment.containerName

foreach ($envName in $Envs) {
  $envCfg = $envs.environments.$envName
  if (-not $envCfg) { throw [string]::Format("Unknown env '{0}'", $envName) }

  $stgName = New-ResourceName -Org $cfg.globals.org -App $cfg.globals.app -Env $envName -RegionCode $envCfg.regionCode -Suffix 'stg'

  # Ensure container exists
  az storage container create --name $container --account-name $stgName --auth-mode login | Out-Null

  $blob = [string]::Format("{0}/{1}/{0}.zip", $App, $version)

  az storage blob upload `
    --account-name $stgName `
    --container-name $container `
    --name $blob `
    --file $pkg `
    --overwrite `
    --auth-mode login | Out-Null

  Write-Host ([string]::Format("Published {0} to storage '{1}' in env '{2}'", $blob, $stgName, $envName))
}
