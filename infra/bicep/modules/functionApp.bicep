param name string
param location string
param storageAccountName string
param appInsightsInstrumentationKey string
param planId string
param runtime string
param tags object

resource plan 'Microsoft.Web/serverfarms@2023-12-01' existing = {
  name: last(split(planId, '/'))
}

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  tags: tags
  properties: {
    httpsOnly: true
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: ''
      appSettings: [
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: runtime }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsightsInstrumentationKey }
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};...' }
      ]
      ftpsState: 'Disabled'
      use32BitWorkerProcess: false
      alwaysOn: true
    }
  }
}

output id string = site.id
