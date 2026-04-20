@description('Location for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Short name prefix used for all resource names (e.g. "eshop")')
@minLength(3)
@maxLength(12)
param namePrefix string = 'eshop'

@description('PostgreSQL administrator username')
param postgresAdminUser string = 'eshopadmin'

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('Tags to apply to all resources')
param tags object = {
  application: 'eShop'
  environment: 'production'
}

// ─── Monitoring ───────────────────────────────────────────────────────────────

module appInsights 'modules/appinsights.bicep' = {
  name: 'appInsights'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

// ─── App Service Plan ─────────────────────────────────────────────────────────

module appServicePlan 'modules/appserviceplan.bicep' = {
  name: 'appServicePlan'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

// ─── Data & Messaging ─────────────────────────────────────────────────────────

module postgres 'modules/postgresql.bicep' = {
  name: 'postgres'
  params: {
    location: location
    namePrefix: namePrefix
    administratorLogin: postgresAdminUser
    administratorLoginPassword: postgresAdminPassword
    tags: tags
  }
}

module redis 'modules/redis.bicep' = {
  name: 'redis'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module serviceBus 'modules/servicebus.bicep' = {
  name: 'serviceBus'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

// ─── App Services ─────────────────────────────────────────────────────────────

var commonSettings = [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsights.outputs.appInsightsConnectionString
  }
  {
    name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
    value: '~3'
  }
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: 'Production'
  }
]

// Identity API
module identityApi 'modules/appservice.bicep' = {
  name: 'identityApi'
  params: {
    location: location
    appName: '${namePrefix}-identity-api'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    tags: tags
    appSettings: concat(commonSettings, [
      {
        name: 'ConnectionStrings__identitydb'
        value: postgres.outputs.identityDbConnectionString
      }
    ])
  }
}

// Catalog API
module catalogApi 'modules/appservice.bicep' = {
  name: 'catalogApi'
  params: {
    location: location
    appName: '${namePrefix}-catalog-api'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    tags: tags
    appSettings: concat(commonSettings, [
      {
        name: 'ConnectionStrings__catalogdb'
        value: postgres.outputs.catalogDbConnectionString
      }
      {
        name: 'ConnectionStrings__EventBus'
        value: serviceBus.outputs.serviceBusEndpoint
      }
      {
        name: 'EventBus__SubscriptionClientName'
        value: 'Catalog'
      }
    ])
  }
}

// Basket API
module basketApi 'modules/appservice.bicep' = {
  name: 'basketApi'
  params: {
    location: location
    appName: '${namePrefix}-basket-api'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    tags: tags
    appSettings: concat(commonSettings, [
      {
        name: 'ConnectionStrings__Redis'
        value: redis.outputs.redisConnectionString
      }
      {
        name: 'ConnectionStrings__EventBus'
        value: serviceBus.outputs.serviceBusEndpoint
      }
      {
        name: 'EventBus__SubscriptionClientName'
        value: 'Basket'
      }
      {
        name: 'Identity__Url'
        value: identityApi.outputs.appServiceUrl
      }
    ])
  }
}

// Ordering API
module orderingApi 'modules/appservice.bicep' = {
  name: 'orderingApi'
  params: {
    location: location
    appName: '${namePrefix}-ordering-api'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    tags: tags
    appSettings: concat(commonSettings, [
      {
        name: 'ConnectionStrings__orderingdb'
        value: postgres.outputs.orderingDbConnectionString
      }
      {
        name: 'ConnectionStrings__EventBus'
        value: serviceBus.outputs.serviceBusEndpoint
      }
      {
        name: 'EventBus__SubscriptionClientName'
        value: 'Ordering'
      }
      {
        name: 'Identity__Url'
        value: identityApi.outputs.appServiceUrl
      }
    ])
  }
}

// Webhooks API
module webhooksApi 'modules/appservice.bicep' = {
  name: 'webhooksApi'
  params: {
    location: location
    appName: '${namePrefix}-webhooks-api'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    tags: tags
    appSettings: concat(commonSettings, [
      {
        name: 'ConnectionStrings__webhooksdb'
        value: postgres.outputs.webhooksDbConnectionString
      }
      {
        name: 'ConnectionStrings__EventBus'
        value: serviceBus.outputs.serviceBusEndpoint
      }
      {
        name: 'EventBus__SubscriptionClientName'
        value: 'Webhooks'
      }
      {
        name: 'Identity__Url'
        value: identityApi.outputs.appServiceUrl
      }
    ])
  }
}

// WebApp (Blazor Frontend)
module webApp 'modules/appservice.bicep' = {
  name: 'webApp'
  params: {
    location: location
    appName: '${namePrefix}-webapp'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    tags: tags
    appSettings: concat(commonSettings, [
      {
        name: 'ConnectionStrings__EventBus'
        value: serviceBus.outputs.serviceBusEndpoint
      }
      {
        name: 'EventBus__SubscriptionClientName'
        value: 'Ordering.webapp'
      }
      {
        name: 'Services__Basket'
        value: basketApi.outputs.appServiceUrl
      }
      {
        name: 'Services__Catalog'
        value: catalogApi.outputs.appServiceUrl
      }
      {
        name: 'Services__Ordering'
        value: orderingApi.outputs.appServiceUrl
      }
      {
        name: 'Identity__Url'
        value: identityApi.outputs.appServiceUrl
      }
    ])
  }
}

// WebhookClient
module webhookClient 'modules/appservice.bicep' = {
  name: 'webhookClient'
  params: {
    location: location
    appName: '${namePrefix}-webhookclient'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    tags: tags
    appSettings: concat(commonSettings, [
      {
        name: 'Identity__Url'
        value: identityApi.outputs.appServiceUrl
      }
      {
        name: 'WebhooksApiUrl'
        value: webhooksApi.outputs.appServiceUrl
      }
    ])
  }
}

// OrderProcessor (Worker)
module orderProcessor 'modules/appservice.bicep' = {
  name: 'orderProcessor'
  params: {
    location: location
    appName: '${namePrefix}-orderprocessor'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    tags: tags
    appSettings: concat(commonSettings, [
      {
        name: 'ConnectionStrings__orderingdb'
        value: postgres.outputs.orderingDbConnectionString
      }
      {
        name: 'ConnectionStrings__EventBus'
        value: serviceBus.outputs.serviceBusEndpoint
      }
      {
        name: 'EventBus__SubscriptionClientName'
        value: 'OrderProcessor'
      }
    ])
  }
}

// PaymentProcessor (Worker)
module paymentProcessor 'modules/appservice.bicep' = {
  name: 'paymentProcessor'
  params: {
    location: location
    appName: '${namePrefix}-paymentprocessor'
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    tags: tags
    appSettings: concat(commonSettings, [
      {
        name: 'ConnectionStrings__EventBus'
        value: serviceBus.outputs.serviceBusEndpoint
      }
      {
        name: 'EventBus__SubscriptionClientName'
        value: 'PaymentProcessor'
      }
    ])
  }
}

// ─── Service Bus Role Assignments (Managed Identity) ─────────────────────────
// Each app service that uses the event bus gets the Azure Service Bus Data Owner
// role on the namespace so it can publish and consume messages via Managed Identity.

module sbRoleCatalog 'modules/servicebus-roleassignment.bicep' = {
  name: 'sbRole-catalog'
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespaceName
    principalId: catalogApi.outputs.principalId
  }
}

module sbRoleBasket 'modules/servicebus-roleassignment.bicep' = {
  name: 'sbRole-basket'
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespaceName
    principalId: basketApi.outputs.principalId
  }
}

module sbRoleOrdering 'modules/servicebus-roleassignment.bicep' = {
  name: 'sbRole-ordering'
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespaceName
    principalId: orderingApi.outputs.principalId
  }
}

module sbRoleWebhooks 'modules/servicebus-roleassignment.bicep' = {
  name: 'sbRole-webhooks'
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespaceName
    principalId: webhooksApi.outputs.principalId
  }
}

module sbRoleWebApp 'modules/servicebus-roleassignment.bicep' = {
  name: 'sbRole-webapp'
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespaceName
    principalId: webApp.outputs.principalId
  }
}

module sbRoleOrderProcessor 'modules/servicebus-roleassignment.bicep' = {
  name: 'sbRole-orderprocessor'
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespaceName
    principalId: orderProcessor.outputs.principalId
  }
}

module sbRolePaymentProcessor 'modules/servicebus-roleassignment.bicep' = {
  name: 'sbRole-paymentprocessor'
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespaceName
    principalId: paymentProcessor.outputs.principalId
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────────

output identityApiUrl string = identityApi.outputs.appServiceUrl
output catalogApiUrl string = catalogApi.outputs.appServiceUrl
output basketApiUrl string = basketApi.outputs.appServiceUrl
output orderingApiUrl string = orderingApi.outputs.appServiceUrl
output webhooksApiUrl string = webhooksApi.outputs.appServiceUrl
output webAppUrl string = webApp.outputs.appServiceUrl
output appInsightsConnectionString string = appInsights.outputs.appInsightsConnectionString
output postgresServerFqdn string = postgres.outputs.serverFqdn
output redisHostName string = redis.outputs.redisHostName
