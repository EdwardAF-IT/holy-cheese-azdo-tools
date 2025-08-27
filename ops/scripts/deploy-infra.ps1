<#
.SYNOPSIS
Deploys infra for a given environment using Bicep. Names are computed via naming.psm1.
#>
param(
  [Parameter(Mandatory)][string] $Env
)
$ErrorActionPreference = 'Stop'

function New-Tag {
    param([string]$Name, [string]$Value)
    return [string]::Format("{0}={1}", $Name, $Value)
}

# Load helpers and configs
. "$PSScriptRoot/_common.ps1"
$cfg = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yml")
$envs = Import-YamlSafely -Path $cfg.paths.envCatalog
$envCfg = $envs.environments.$Env
if (-not $envCfg) { throw [string]::Format("Unknown env '{0}'", $Env) }

# Import naming
$namePath = [IO.Path]::Combine($PSScriptRoot, '../..', $cfg.paths.namingModule)
Import-Module $namePath -Force

# Select subscription
$subId = $cfg.globals.subscriptionId
az account set --subscription $subId | Out-Null

# Subscription-level resources
$sharedRg = $cfg.shared.resourceGroup
$location = $cfg.globals.location
Write-Host ([string]::Format("Ensuring shared RG '{0}' exists in location '{1}'", $sharedRg, $location))
$tagOrg   = New-Tag 'org'   $cfg.globals.org
$tagApp   = New-Tag 'app'   $cfg.globals.app
$tagScope = New-Tag 'scope' 'shared'
az group create `
    -n $sharedRg `
    -l $location `
    --tags $tagOrg $tagApp $tagScope | Out-Null

# Deploy shared Bicep
if (-not (Test-Path $cfg.paths.bicep.shared)) {
    throw [string]::Format("Shared Bicep file not found: {0}", $cfg.paths.bicep.shared)
}
Write-Host ([string]::Format("Deploying shared infra from {0}", $cfg.paths.bicep.shared))
$deployment = az deployment group create `
    -g $sharedRg `
    -f $cfg.paths.bicep.shared `
    -p resourceGroupName=$sharedRg `
       subscriptionId=$cfg.globals.subscriptionId `
       location=$location `
       tags=$tagString `
    --query 'properties.outputs' `
    -o json | ConvertFrom-Json

# Compute names once via naming module
$org = $cfg.globals.org
$app = $cfg.globals.app
$region = $envCfg.regionCode
$aiName = $cfg.shared.appInsightsName
$aspName = $cfg.shared.planName

$aiKey = $deployment.instrumentationKey.value
$aiConnection = $deployment.connectionString.value
$planId = az appservice plan show -g $sharedRg -n $aspName --query 'id' -o tsv
$rgName = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'rg'
$stgName = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'stg'
$fnName  = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'func'
$kvName  = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'kv'

# Ensure RG exists with tags
$tags = $envCfg.tags
az group create `
    -n $rgName `
    -l $envCfg.location `
    --tags $tags | Out-Null

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
