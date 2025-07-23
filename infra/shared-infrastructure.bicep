param resourceGroupName string
param location string
param subscriptionId string
param tags object

output rgName string = resourceGroupName
output subId string = subscriptionId

resource sharedInsights 'microsoft.insights/components@2020-02-02' = {
  name: 'AzdoTools-Shared-Insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 90
  }
  tags: tags
}

resource sharedPlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: 'AzdoTools-AppServicePlan-Shared'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
  tags: tags
}
