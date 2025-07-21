param appName string
param location string
param hostingPlanName string
param insightsId string
param storageAccountName string

resource hostingPlan 'Microsoft.Web/serverfarms@2024-11-01' existing = {
  name: hostingPlanName
}

resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: appName
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: insightsId
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};...'
        }
      ]
    }
  }
}
