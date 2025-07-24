param location string
param appName string
param environmentName string
param subscriptionId string

var tags = {
  App: appName
  Environment: environmentName
  Owner: 'Edward'
}

var prefix = '${appName}-${environmentName}'
var sharedInsightsId = '/subscriptions/${subscriptionId}/resourceGroups/${appName}-RG-Shared/providers/microsoft.insights/components/azdotools-shared-insights'
var sharedHostingPlanName = '${appName}-AppServicePlan-Shared'

// Key Vault
module kv '../modules/keyVault.bicep' = {
  name: '${prefix}-kv'
  params: {
    kvName: '${prefix}-kv'
    location: location
    tags: tags
  }
}

// Storage Account
module storage '../modules/storage.bicep' = {
  name: '${prefix}-storage'
  params: {
    storageName: toLower('${prefix}storage')
    location: location
    tags: tags
  }
}

// Function App
module fnapp '../modules/functionApp.bicep' = {
  name: '${prefix}-fnapp'
  params: {
    appName: prefix
    location: location
    hostingPlanName: sharedHostingPlanName
    insightsId: sharedInsightsId
    storageAccountName: storage.outputs.storageName
    tags: tags
  }
}
