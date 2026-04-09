@description('Location for all resources')
param location string

@description('Name prefix for resources')
param namePrefix string

@description('Tags to apply to resources')
param tags object = {}

// Standard SKU: required for topics (pub/sub pattern), no premium needed for no private connectivity
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: '${namePrefix}-servicebus'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    // Public access - no private connectivity for cost optimization
    publicNetworkAccess: 'Enabled'
  }
}

// Topics for each integration event
var topics = [
  'OrderStartedIntegrationEvent'
  'OrderStatusChangedToAwaitingValidationIntegrationEvent'
  'OrderStatusChangedToPaidIntegrationEvent'
  'OrderStatusChangedToStockConfirmedIntegrationEvent'
  'OrderStatusChangedToCancelledIntegrationEvent'
  'OrderStatusChangedToShippedIntegrationEvent'
  'ProductPriceChangedIntegrationEvent'
  'UserCheckoutAcceptedIntegrationEvent'
  'OrderPaymentFailedIntegrationEvent'
  'OrderPaymentSucceededIntegrationEvent'
]

resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = [for topic in topics: {
  parent: serviceBusNamespace
  name: topic
  properties: {
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    enableBatchedOperations: true
  }
}]

// Subscriptions for each service
var subscriptions = [
  { topic: 'OrderStartedIntegrationEvent', name: 'Basket' }
  { topic: 'OrderStatusChangedToAwaitingValidationIntegrationEvent', name: 'Ordering' }
  { topic: 'OrderStatusChangedToPaidIntegrationEvent', name: 'Ordering' }
  { topic: 'OrderStatusChangedToStockConfirmedIntegrationEvent', name: 'Ordering' }
  { topic: 'OrderStatusChangedToCancelledIntegrationEvent', name: 'Ordering' }
  { topic: 'OrderStatusChangedToShippedIntegrationEvent', name: 'Ordering' }
  { topic: 'ProductPriceChangedIntegrationEvent', name: 'Basket' }
  { topic: 'UserCheckoutAcceptedIntegrationEvent', name: 'Ordering' }
  { topic: 'OrderPaymentFailedIntegrationEvent', name: 'OrderProcessor' }
  { topic: 'OrderPaymentSucceededIntegrationEvent', name: 'OrderProcessor' }
  { topic: 'OrderStatusChangedToPaidIntegrationEvent', name: 'Catalog' }
  { topic: 'OrderStatusChangedToStockConfirmedIntegrationEvent', name: 'PaymentProcessor' }
  { topic: 'OrderStatusChangedToAwaitingValidationIntegrationEvent', name: 'Catalog' }
  { topic: 'OrderStatusChangedToCancelledIntegrationEvent', name: 'Webhooks' }
  { topic: 'OrderStatusChangedToShippedIntegrationEvent', name: 'Webhooks' }
]

resource serviceBusSubscriptions 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = [for sub in subscriptions: {
  name: '${serviceBusNamespace.name}/${sub.topic}/${sub.name}'
  properties: {
    defaultMessageTimeToLive: 'P14D'
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    enableBatchedOperations: true
    deadLetteringOnMessageExpiration: true
  }
  dependsOn: [
    serviceBusTopics
  ]
}]

var rootKey = listKeys('${serviceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey', serviceBusNamespace.apiVersion)

output serviceBusNamespaceName string = serviceBusNamespace.name
output serviceBusEndpoint string = serviceBusNamespace.properties.serviceBusEndpoint
output serviceBusConnectionString string = rootKey.primaryConnectionString
