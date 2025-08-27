<#
.SYNOPSIS
Deploys infra for a given environment using Bicep. Names are computed via naming.psm1.
#>
param(
  [Parameter(Mandatory)][string] $Env
)
$ErrorActionPreference = 'Stop'

# Load helpers and configs
. "$PSScriptRoot/_common.ps1"
$cfg = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yml")
$envs = Import-YamlSafely -Path ([IO.Path]::Combine($PSScriptRoot, '..', $cfg.paths.envCatalog))
$envCfg = $envs.environments.$Env
if (-not $envCfg) { throw [string]::Format("Unknown env '{0}'", $Env) }

# Import naming
$namePath = [IO.Path]::Combine($PSScriptRoot, '..', $cfg.paths.namingModule)
Import-Module $namePath -Force

# Select subscription
$subId = $cfg.globals.subscriptionId
az account set --subscription $subId | Out-Null

# Compute names once via naming module
$org = $cfg.globals.org
$app = $cfg.globals.app
$region = $envCfg.regionCode
$sharedRg = $cfg.shared.resourceGroup
$aiName = $cfg.shared.appInsightsName
$aspName = $cfg.shared.planName

$aiKey = az monitor app-insights component show -g $sharedRg -n $aiName --query 'InstrumentationKey' -o tsv
$planId = az appservice plan show -g $sharedRg -n $aspName --query 'id' -o tsv
$rgName = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'rg'
$stgName = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'stg'
$fnName  = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'func'
$kvName  = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'kv'

# Ensure RG exists with tags
$tags = $envCfg.tags
az group create -n $rgName -l $envCfg.location --tags $tags | Out-Null

# Deploy Bicep at resource-group scope, passing precomputed names
$bicep = $cfg.paths.bicepMain
$runtime = $envCfg.function.runtime
$sku = $envCfg.function.sku

az deployment group create `
  -g $rgName `
  -f $bicep `
  -p env=$Env location=$($envCfg.location) regionCode=$region `
     org=$org app=$app `
     rgName=$rgName storageName=$stgName appInsightsName=$aiName planName=$aspName functionAppName=$fnName keyVaultName=$kvName `
     functionSku=$sku runtime=$runtime `
  --only-show-errors

# Mark infra ready
az group update -n $rgName --set tags.org\\:infraReady=true | Out-Null
Write-Host ([string]::Format("Infra deployed and marked ready for env '{0}'", $Env))
