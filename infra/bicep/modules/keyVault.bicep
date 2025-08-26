param name string
param location string
param tags object

resource kv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: name
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: { name: 'standard', family: 'A' }
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    enabledForTemplateDeployment: true
    enableSoftDelete: true
  }
  tags: tags
}

output id string = kv.id
