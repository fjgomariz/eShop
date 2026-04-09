@description('Location for all resources')
param location string

@description('Name prefix for resources')
param namePrefix string

@description('Tags to apply to resources')
param tags object = {}

// B2 Linux plan: cost-effective for .NET workloads without private networking overhead
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${namePrefix}-plan'
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: 'B2'
    tier: 'Basic'
    capacity: 1
  }
  properties: {
    reserved: true // Required for Linux
  }
}

output appServicePlanId string = appServicePlan.id
