targetScope = 'subscription'

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

@description('Precomputed name for the shared resource group')
param sharedRg string

@description('Functions runtime, e.g., dotnet-isolated')
param runtime string

var commonTags = {
  org: org
  app: app
  env: env
}

// Create or ensure the RG exists at subscription scope
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: commonTags
}

resource sharedRgRes 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: sharedRg
  location: location
  tags: commonTags
}
