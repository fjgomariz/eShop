@description('Location for all resources')
param location string

@description('Name prefix for resources')
param namePrefix string

@description('Tags to apply to resources')
param tags object = {}

// Basic C1 (1 GB): cheaper option, no private connectivity
resource redisCache 'Microsoft.Cache/redis@2024-03-01' = {
  name: '${namePrefix}-redis'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 1
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    // Public access - no private connectivity for cost optimization
    publicNetworkAccess: 'Enabled'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

output redisCacheName string = redisCache.name
output redisHostName string = redisCache.properties.hostName
output redisPort int = redisCache.properties.sslPort
output redisPrimaryKey string = redisCache.listKeys().primaryKey
output redisConnectionString string = '${redisCache.properties.hostName}:${redisCache.properties.sslPort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
