param environmentName string
param appName string
param location string = 'centralus'

var resourceGroupName = 'hc-${appName}-${environmentName}-rg'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module appInfra './environments/${appName}-${environmentName}.bicep' = {
  name: '${appName}-${environmentName}-deploy'
  scope: rg
  params: {
    location: location
    appName: appName
    environmentName: environmentName
  }
}
