@description('Location for all resources')
param location string

@description('Name prefix for resources')
param namePrefix string

@description('PostgreSQL admin username')
param administratorLogin string

@description('PostgreSQL admin password')
@secure()
param administratorLoginPassword string

@description('Tags to apply to resources')
param tags object = {}

// Burstable B1ms: cheapest option for dev/test, no private connectivity needed
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2025-08-01' = {
  name: '${namePrefix}-postgres'
  location: location
  tags: tags
  sku: {
    name: 'Standard_B2s'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: '18'
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    // Public access - no private connectivity for cost optimization
    network: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// Allow Azure services to access PostgreSQL
resource allowAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2025-08-01' = {
  parent: postgresServer
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource catalogDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2025-08-01' = {
  parent: postgresServer
  name: 'CatalogDB'
}

resource orderingDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2025-08-01' = {
  parent: postgresServer
  name: 'OrderingDB'
}

resource identityDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2025-08-01' = {
  parent: postgresServer
  name: 'IdentityDB'
}

resource webhooksDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2025-08-01' = {
  parent: postgresServer
  name: 'WebhooksDB'
}

var connectionStringBase = 'Host=${postgresServer.properties.fullyQualifiedDomainName};Username=${administratorLogin};Password=${administratorLoginPassword};SSL Mode=Require;Trust Server Certificate=true'

output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName
output catalogDbConnectionString string = '${connectionStringBase};Database=CatalogDB'
output orderingDbConnectionString string = '${connectionStringBase};Database=OrderingDB'
output identityDbConnectionString string = '${connectionStringBase};Database=IdentityDB'
output webhooksDbConnectionString string = '${connectionStringBase};Database=WebhooksDB'
