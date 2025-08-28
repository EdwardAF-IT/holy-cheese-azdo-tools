<#
.SYNOPSIS
Deploys infra for a given environment using Bicep. Names are computed via naming.psm1.
#>
param(
  [Parameter(Mandatory)][string] $Env
)
$ErrorActionPreference = 'Stop'

function New-TagsJson {
    <#
    .SYNOPSIS
        Builds an Azure CLI/Bicep‑friendly tags JSON string.

    .DESCRIPTION
        Accepts one or more name/value pairs and returns a JSON object string
        that can be passed to `az deployment ... -p tags="..."` without
        CLI parsing errors.

    .EXAMPLE
        $tags = New-TagsJson -Tags @{ org = 'holycheese'; app = 'azdotools'; scope = 'shared' }
        az group create -n MyRG -l centralus --tags $tags
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Tags
    )

    # Convert to JSON and strip newlines/indentation
    $json = $Tags | ConvertTo-Json -Compress
    return $json
}
Set-PSDebug -Trace 1
# Load helpers and configs
Import-Module "$PSScriptRoot/_common.psm1" -Force
$cfg = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yml")
$envs = Import-YamlSafely -Path $cfg.paths.envCatalog
$envCfg = $envs.environments.$Env
if (-not $envCfg) { throw [string]::Format("Unknown env '{0}'", $Env) }

# Import naming
$namePath = [IO.Path]::Combine($PSScriptRoot, '../..', $cfg.paths.namingModule)
Import-Module $namePath -Force

# Select subscription
$subId = ($cfg.globals.subscriptionId | Out-String).Trim()
Write-Host "DEBUG: Just assigned subId='$subId' (len=$($subId.Length))"
Write-Host "DEBUG at guard: cfg.globals.subscriptionId = '$($cfg.globals.subscriptionId)'"
Write-Host "DEBUG at guard: subId = '$subId'"
Write-Host "DEBUG at guard: cfg type = $($cfg.GetType().FullName)"
Write-Host "DEBUG at guard: subId type = $($subId.GetType().FullName)"

if ([string]::IsNullOrWhiteSpace($subId)) {
    throw "Subscription Id is missing or empty in config.yml"
}

az account set --subscription $subId | Out-Null

# Subscription-level resources
$sharedRg = $cfg.shared.resourceGroup
$location = $cfg.globals.location
$sharedBicepPath = $cfg.paths.bicep.shared
Write-Host ("Ensuring shared RG '{0}' exists in location '{1}'" -f $sharedRg, $location)

az group create `
    -n $sharedRg `
    -l $location `
    --tags (New-TagsJson -Tags @{
        org   = $cfg.globals.org
        app   = $cfg.globals.app
        scope = 'shared'
    }) | Out-Null

Write-Host ("Deploying shared infra from {0}" -f $sharedBicepPath)

# Run deployment and capture raw output
$jsonRaw = az deployment group create `
    -g $sharedRg `
    -f $sharedBicepPath `
    -p resourceGroupName=$sharedRg `
       subscriptionId=$subId `
       location=$location `
       tags=(New-TagsJson -Tags @{
           org   = $cfg.globals.org
           app   = $cfg.globals.app
           scope = 'shared'
       }) `
    --debug `
    -o json

# Debug: show exactly what came back
Write-Host "----- Raw CLI output start -----"
Write-Host $jsonRaw
Write-Host "----- Raw CLI output end -----"

# Check exit code before parsing
if ($LASTEXITCODE -ne 0) {
    throw "Shared Bicep deployment failed — see raw output above."
}

# Guard against empty or whitespace‑only output
if ([string]::IsNullOrWhiteSpace($jsonRaw)) {
    throw "No outputs were returned from the shared Bicep deployment."
}

# Finally, parse JSON
$deployment = $jsonRaw | ConvertFrom-Json

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
