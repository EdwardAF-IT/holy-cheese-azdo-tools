param location string
param appName string
param environmentName string
param tags object = {}
param subscriptionId string

var tagsAll = union({
  App: appName
  Environment: environmentName
  Owner: 'Edward'
}, tags)

var prefix = '${appName}-${environmentName}'
var safePrefix = toLower('${appName}${environmentName}')
var sharedInsightsId = '/subscriptions/${subscriptionId}/resourceGroups/${appName}-RG-Shared/providers/microsoft.insights/components/azdotools-shared-insights'
var sharedHostingPlanName = '${appName}-AppServicePlan-Shared'
var sharedHostingPlanId = '/subscriptions/${subscriptionId}/resourceGroups/${appName}-RG-Shared/providers/Microsoft.Web/serverfarms/${sharedHostingPlanName}'

// Key Vault
module kv '../modules/keyVault.bicep' = {
  name: '${prefix}-kv'
  params: {
    kvName: '${prefix}-kv'
    location: location
    tags: tagsAll
  }
}

// Storage Account
module storage '../modules/storage.bicep' = {
  name: '${prefix}storage'
  params: {
    storageName: toLower('${safePrefix}storage1')
    location: location
    tags: tagsAll
  }
}

// Function App
module fnapp '../modules/functionApp.bicep' = {
  name: '${prefix}-fnapp'
  dependsOn: [
    storage
  ]
  params: {
    appName: prefix
    location: location
    hostingPlanId: sharedHostingPlanId
    insightsId: sharedInsightsId
    storageAccountName: storage.outputs.storageName
    tags: tagsAll
  }
}
