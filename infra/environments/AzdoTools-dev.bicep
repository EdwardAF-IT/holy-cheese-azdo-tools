param location string
param appName string
param environmentName string

var prefix = '${appName}-${environmentName}'

// Application Insights
module insights './modules/appInsights.bicep' = {
  name: '${prefix}-insights'
  params: {
    insightsName: '${prefix}-insights'
    location: location
  }
}

// Key Vault
module kv './modules/keyVault.bicep' = {
  name: '${prefix}-kv'
  params: {
    kvName: '${prefix}-kv'
    location: location
  }
}

// Storage Account
module storage './modules/storage.bicep' = {
  name: '${prefix}-storage'
  params: {
    storageName: toLower('${prefix}storage')
    location: location
  }
}

// Function App
module fnapp './modules/functionApp.bicep' = {
  name: '${prefix}-fnapp'
  params: {
    appName: prefix
    location: location
    hostingPlanName: 'ASP-${prefix}'
    insightsId: insights.outputs.insightsId
    storageAccountName: storage.outputs.storageName
  }
}
