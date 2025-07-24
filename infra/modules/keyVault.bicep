param kvName string
param location string
param tags object

resource keyVault 'Microsoft.KeyVault/vaults@2024-12-01-preview' = {
  name: kvName
  location: location
  properties: {
    sku: { name: 'Standard', family: 'A' }
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}
