param appName string
param location string
param hostingPlanId string
param insightsId string
param storageAccountName string
param tags object

resource hostingPlan 'Microsoft.Web/serverfarms@2024-11-01' existing = {
  name: last(split(hostingPlanId, '/'))
}

resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: appName
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: hostingPlanId
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
  tags: tags
}

output functionAppName string = functionApp.name