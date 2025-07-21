param storageName string
param location string

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS'; tier: 'Standard' }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: { enabled: true; keyType: 'Account' }
        file: { enabled: true; keyType: 'Account' }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}
