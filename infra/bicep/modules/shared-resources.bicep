param resourceGroupName string
param location string
param subscriptionId string
param tags object

output rgName string = resourceGroupName
output subId string = subscriptionId

resource ai 'microsoft.insights/components@2020-02-02' = {
  name: 'AzdoTools-Shared-Insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 30
    DisableIpMasking: true
  }
  tags: tags
}

output aiID string = ai.id
output instrumentationKey string = ai.properties.InstrumentationKey
output connectionString string = ai.properties.ConnectionString

resource plan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: 'AzdoTools-AppServicePlan-Shared'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
  tags: tags
}

output planID string = plan.id