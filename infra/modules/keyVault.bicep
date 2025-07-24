param kvName string
param location string
param tags object

resource keyVault 'Microsoft.KeyVault/vaults@2024-12-01-preview' = {
  name: kvName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: { name: 'standard', family: 'A' }
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}

output kvName string = keyVault.name