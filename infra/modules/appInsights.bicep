param insightsName string
param location string
param tags object

resource appInsights 'microsoft.insights/components@2020-02-02' = {
  name: insightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 90
  }
  tags: tags
}

output insightsName string = appInsights.name