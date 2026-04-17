@description('Location for all resources')
param location string

@description('Name for the app service')
param appName string

@description('App Service Plan ID')
param appServicePlanId string

@description('App settings (environment variables)')
param appSettings array = []

@description('Tags to apply to resources')
param tags object = {}

resource appService 'Microsoft.Web/sites@2025-03-01' = {
  name: appName
  location: location
  tags: tags
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      alwaysOn: false
      http20Enabled: true
      minTlsVersion: '1.2'
      appSettings: appSettings
    }
  }
}

output appServiceName string = appService.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output appServiceId string = appService.id
// output principalId string = appService.identity == null ? '' : appService.identity.principalId
