param environmentName string
param appName string
param location string = 'centralus'

module appInfra './environments/${appName}-${environmentName}.bicep' = {
  name: '${appName}-${environmentName}-deploy'
  scope: rg
  params: {
    location: location
    appName: appName
    environmentName: environmentName
  }
}
