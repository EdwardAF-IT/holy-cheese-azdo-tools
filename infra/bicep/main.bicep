@description('Environment like dev/test/prod')
param env string
@description('Azure location, e.g., centralus')
param location string
@description('Short region code, e.g., cus')
param regionCode string
@description('Org token for tags')
param org string
@description('App token for tags')
param app string

@description('Precomputed names to avoid duplicating naming logic')
param rgName string
param storageName string
param appInsightsName string
param planName string
param functionAppName string
param keyVaultName string

@description('SKU for the Function Plan (EP1/EP2/...)')
param functionSku string
@description('Functions runtime, e.g., dotnet-isolated')
param runtime string

var commonTags = {
  org: org
  app: app
  env: env
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: rgName
}

module stg 'modules/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: storageName
    location: location
    tags: commonTags
  }
}

module kv 'modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: keyVaultName
    location: location
    tags: commonTags
  }
}

module func 'modules/functionapp.bicep' = {
  name: 'functionapp'
  scope: rg
  params: {
    name: functionAppName
    location: location
    storageAccountName: storageName
    appInsightsInstrumentationKey: ai.outputs.instrumentationKey
    planId: plan.outputs.id
    runtime: runtime
    tags: commonTags
  }
}
