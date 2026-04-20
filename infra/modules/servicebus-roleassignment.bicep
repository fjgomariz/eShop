@description('Name of the Service Bus namespace to assign the role on')
param serviceBusNamespaceName string

@description('Principal ID of the managed identity to grant access')
param principalId string

// Azure Service Bus Data Owner built-in role
var serviceBusDataOwnerRoleId = '090c5cfd-751d-490a-894a-3ce6f1109419'

resource existingServiceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: serviceBusNamespaceName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingServiceBusNamespace.id, principalId, serviceBusDataOwnerRoleId)
  scope: existingServiceBusNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataOwnerRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
