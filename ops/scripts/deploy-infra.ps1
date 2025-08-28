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
    $invalidCharsPattern = '[<>%&\\?/]'   # backslash must be escaped

    $safeTags = @{}
    foreach ($key in $Tags.Keys) {
        $safeKey = $key -replace $invalidCharsPattern, ''
        $safeKey = $safeKey -replace '\\:', ':'
        $safeTags[$safeKey] = $Tags[$key]
    }
    return ($safeTags | ConvertTo-Json -Compress)
}

# Load helpers and configs
Import-Module "$PSScriptRoot/_common.psm1" -Force
$cfg   = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yml")
$envs  = Import-YamlSafely -Path $cfg.paths.envCatalog
$envCfg = $envs.environments.$Env
if (-not $envCfg) { throw [string]::Format("Unknown env '{0}'", $Env) }

# Import naming
$namePath = [IO.Path]::Combine($PSScriptRoot, '../..', $cfg.paths.namingModule)
Import-Module $namePath -Force

# Select subscription
$subId = ($cfg.globals.subscriptionId | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($subId)) {
    throw "Subscription Id is missing or empty in config.yml"
}
az account set --subscription $subId | Out-Null

# Compute common values
$org     = $cfg.globals.org
$app     = $cfg.globals.app
$region  = $envCfg.regionCode
$aiName  = $cfg.shared.appInsightsName
$aspName = $cfg.shared.planName
$runtime = $envCfg.function.runtime
$sku     = $envCfg.function.sku

$rgName  = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'rg'
$stgName = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'stg'
$fnName  = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'func'
$kvName  = New-ResourceName -Org $org -App $app -Env $Env -RegionCode $region -Suffix 'kv'

$sharedRg        = $cfg.shared.resourceGroup
$location        = $cfg.globals.location
$bicepRg         = $cfg.paths.bicep.rgScoped
$bicepSub        = $cfg.paths.bicep.subScoped
$sharedBicepPath = $cfg.paths.bicep.shared

# ---------- Deploy subscription‑scoped (creates RGs, any sub‑level resources) ----------
$subTags = New-TagsJson -Tags @{
    org   = $org
    app   = $app
    scope = 'shared'
}
az deployment sub create `
    --location $location `
    --template-file $bicepSub `
    --parameters env=$Env location=$($envCfg.location) regionCode=$region `
                 org=$org app=$app `
                 rgName=$rgName sharedRg=$sharedRg `
                 tags="$subTags" `
    --only-show-errors

# ---------- Deploy shared RG‑scoped (App Insights + App Service Plan) ----------
Write-Host ("Ensuring shared RG '{0}' exists in location '{1}'" -f $sharedRg, $location)
az group create -n $sharedRg -l $location --tags "$subTags"

$jsonRaw = az deployment group create `
    -g $sharedRg `
    -f $sharedBicepPath `
    -p env=$Env location=$location regionCode=$region `
       org=$org app=$app `
       appInsightsName=$aiName planName=$aspName `
       tags="$subTags" `
    --query 'properties.outputs' `
    -o json

Write-Host "----- Raw CLI output start -----"
Write-Host $jsonRaw
Write-Host "----- Raw CLI output end -----"
if ($LASTEXITCODE -ne 0) { throw "Shared Bicep deployment failed — see raw output above." }
if ([string]::IsNullOrWhiteSpace($jsonRaw)) { throw "No outputs were returned from the shared Bicep deployment." }

$deployment   = $jsonRaw | ConvertFrom-Json
$aiKey        = $deployment.instrumentationKey.value
$aiConnection = $deployment.connectionString.value
$planId       = az appservice plan show -g $sharedRg -n $aspName --query 'id' -o tsv

# ---------- Deploy env RG‑scoped (Storage, KV, Function App) ----------
$envTags = $envCfg.tags
az group create -n $rgName -l $envCfg.location --tags "$envTags" | Out-Null

az deployment group create `
    -g $rgName `
    -f $bicepRg `
    -p env=$Env location=$($envCfg.location) regionCode=$region `
       org=$org app=$app `
       rgName=$rgName storageName=$stgName keyVaultName=$kvName `
       functionAppName=$fnName appInsightsInstrumentationKey=$aiKey `
       planId=$planId functionSku=$sku runtime=$runtime `
       tags="$envTags" `
    --only-show-errors

Write-Host ([string]::Format("Infra deployed env '{0}'", $Env))