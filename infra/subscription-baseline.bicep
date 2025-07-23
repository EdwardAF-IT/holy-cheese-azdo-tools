targetScope = 'subscription'

param rgSuffixes array
param projectPrefix string = 'AzdoTools'
param location string = 'centralus'

resource resourceGroups 'Microsoft.Resources/resourceGroups@2021-04-01' = [
  for suffix in rgSuffixes: {
    name: '${projectPrefix}-RG-${toUpper(substring(suffix, 0, 1))}${substring(suffix, 1)}'
    location: location
  }
]
