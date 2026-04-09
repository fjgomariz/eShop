# eShop Azure Deployment Guide

This guide describes how to deploy the eShop application to Azure using a traditional architecture with Application Gateway, API Management (APIM), and App Services.

## Architecture Overview

```
Internet
    ?
Azure Application Gateway (WAF)
    ?
Azure API Management
    ?
???????????????????????????????????????????????????
?              App Services (Backend)             ?
???????????????????????????????????????????????????
? - WebApp (Blazor Frontend)                      ?
? - Basket.API (gRPC/REST API)                    ?
? - Catalog.API (REST API)                        ?
? - Ordering.API (REST API)                       ?
? - Identity.API (IdentityServer)                 ?
? - Webhooks.API (REST API)                       ?
? - WebhookClient (Blazor App)                    ?
???????????????????????????????????????????????????
?         Background Services (Workers)           ?
? - OrderProcessor (Worker Service)               ?
? - PaymentProcessor (Worker Service)             ?
???????????????????????????????????????????????????
    ?
???????????????????????????????????????????????????
?           Azure PaaS Services                   ?
???????????????????????????????????????????????????
? - Azure Database for PostgreSQL                 ?
? - Azure Cache for Redis                         ?
? - Azure Service Bus (or RabbitMQ on VM/AKS)     ?
???????????????????????????????????????????????????
```

## Prerequisites

- Azure subscription
- Azure CLI installed
- .NET 10 SDK installed
- Visual Studio 2022 or VS Code

## Azure Resources Required

### 1. Resource Group
Create a resource group to contain all resources:
```bash
az group create --name rg-eshop --location eastus
```

### 2. Azure Database for PostgreSQL
Create a PostgreSQL Flexible Server:
```bash
az postgres flexible-server create \
  --resource-group rg-eshop \
  --name eshop-postgres \
  --location eastus \
  --admin-user eshopadmin \
  --admin-password <YourPassword> \
  --sku-name Standard_D2s_v3 \
  --tier GeneralPurpose \
  --version 15
```

Create databases:
```bash
az postgres flexible-server db create --resource-group rg-eshop --server-name eshop-postgres --database-name CatalogDB
az postgres flexible-server db create --resource-group rg-eshop --server-name eshop-postgres --database-name OrderingDB
az postgres flexible-server db create --resource-group rg-eshop --server-name eshop-postgres --database-name IdentityDB
az postgres flexible-server db create --resource-group rg-eshop --server-name eshop-postgres --database-name WebhooksDB
```

### 3. Azure Cache for Redis
```bash
az redis create \
  --resource-group rg-eshop \
  --name eshop-redis \
  --location eastus \
  --sku Standard \
  --vm-size c1
```

### 4. Azure Service Bus (Alternative to RabbitMQ)
```bash
az servicebus namespace create \
  --resource-group rg-eshop \
  --name eshop-servicebus \
  --location eastus \
  --sku Standard
```

Or alternatively, deploy RabbitMQ on a VM or AKS cluster.

### 5. App Service Plan
Create an App Service Plan to host the web apps:
```bash
az appservice plan create \
  --resource-group rg-eshop \
  --name eshop-plan \
  --location eastus \
  --sku P1V3 \
  --is-linux
```

### 6. App Services
Create App Services for each API and web application:

```bash
# Identity API
az webapp create --resource-group rg-eshop --plan eshop-plan --name eshop-identity-api --runtime "DOTNETCORE:10.0"

# Basket API
az webapp create --resource-group rg-eshop --plan eshop-plan --name eshop-basket-api --runtime "DOTNETCORE:10.0"

# Catalog API
az webapp create --resource-group rg-eshop --plan eshop-plan --name eshop-catalog-api --runtime "DOTNETCORE:10.0"

# Ordering API
az webapp create --resource-group rg-eshop --plan eshop-plan --name eshop-ordering-api --runtime "DOTNETCORE:10.0"

# Webhooks API
az webapp create --resource-group rg-eshop --plan eshop-plan --name eshop-webhooks-api --runtime "DOTNETCORE:10.0"

# Web App (Frontend)
az webapp create --resource-group rg-eshop --plan eshop-plan --name eshop-webapp --runtime "DOTNETCORE:10.0"

# Webhook Client
az webapp create --resource-group rg-eshop --plan eshop-plan --name eshop-webhookclient --runtime "DOTNETCORE:10.0"

# Order Processor (Worker Service)
az webapp create --resource-group rg-eshop --plan eshop-plan --name eshop-orderprocessor --runtime "DOTNETCORE:10.0"

# Payment Processor (Worker Service)
az webapp create --resource-group rg-eshop --plan eshop-plan --name eshop-paymentprocessor --runtime "DOTNETCORE:10.0"
```

### 7. Azure API Management
```bash
az apim create \
  --resource-group rg-eshop \
  --name eshop-apim \
  --location eastus \
  --publisher-email admin@eshop.com \
  --publisher-name "eShop" \
  --sku-name Developer
```

### 8. Application Gateway (Optional, for WAF)
Create an Application Gateway with WAF for additional security.

## Configuration

### Connection Strings

Update the connection strings in Azure App Service Configuration for each service:

#### Identity.API
```
identitydb=Host=eshop-postgres.postgres.database.azure.com;Database=IdentityDB;Username=eshopadmin;Password=<password>;SSL Mode=Require
```

#### Catalog.API
```
catalogdb=Host=eshop-postgres.postgres.database.azure.com;Database=CatalogDB;Username=eshopadmin;Password=<password>;SSL Mode=Require
EventBus=Endpoint=sb://eshop-servicebus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<key>
```

#### Ordering.API
```
orderingdb=Host=eshop-postgres.postgres.database.azure.com;Database=OrderingDB;Username=eshopadmin;Password=<password>;SSL Mode=Require
EventBus=Endpoint=sb://eshop-servicebus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<key>
```

#### Basket.API
```
Redis=eshop-redis.redis.cache.windows.net:6380,password=<password>,ssl=True,abortConnect=False
EventBus=Endpoint=sb://eshop-servicebus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<key>
```

#### Webhooks.API
```
webhooksdb=Host=eshop-postgres.postgres.database.azure.com;Database=WebhooksDB;Username=eshopadmin;Password=<password>;SSL Mode=Require
EventBus=Endpoint=sb://eshop-servicebus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<key>
```

### Application Settings

Set application settings for each service using Azure CLI:

```bash
# Example for Basket.API
az webapp config appsettings set \
  --resource-group rg-eshop \
  --name eshop-basket-api \
  --settings Identity__Url=https://eshop-identity-api.azurewebsites.net
```

### Service URLs

Update appsettings for WebApp:
```json
{
  "Services": {
    "Basket": "https://eshop-basket-api.azurewebsites.net",
    "Catalog": "https://eshop-catalog-api.azurewebsites.net",
    "Ordering": "https://eshop-ordering-api.azurewebsites.net"
  },
  "Identity": {
    "Url": "https://eshop-identity-api.azurewebsites.net"
  }
}
```

## Deployment Steps

### 1. Build and Publish

For each project, build and publish:

```bash
# Example for Catalog.API
cd src/Catalog.API
dotnet publish -c Release -o ./publish

# Deploy to Azure
az webapp deployment source config-zip \
  --resource-group rg-eshop \
  --name eshop-catalog-api \
  --src ./publish.zip
```

### 2. Configure APIM

Import each API into API Management:

1. Go to Azure Portal ? API Management
2. Add APIs for Basket, Catalog, Ordering, Webhooks
3. Configure backend URLs to point to App Services
4. Set up authentication and authorization policies
5. Configure rate limiting and throttling

### 3. Configure Application Gateway (Optional)

1. Create backend pools pointing to APIM
2. Configure HTTP settings
3. Set up routing rules
4. Enable WAF with OWASP ruleset

## Security Considerations

1. **Enable Managed Identity** for App Services to access Azure resources
2. **Store secrets** in Azure Key Vault
3. **Enable HTTPS only** for all App Services
4. **Configure CORS** appropriately
5. **Enable WAF** on Application Gateway
6. **Use Azure AD** for authentication instead of IdentityServer (optional upgrade)
7. **Enable Private Endpoints** for PostgreSQL and Redis
8. **Configure Network Security Groups** appropriately

## Monitoring and Diagnostics

1. Enable Application Insights for all App Services
2. Configure Log Analytics workspace
3. Set up alerts for critical metrics
4. Enable diagnostic logs

```bash
az monitor app-insights component create \
  --resource-group rg-eshop \
  --app eshop-insights \
  --location eastus \
  --application-type web
```

## Cost Optimization

1. Use **Azure Reserved Instances** for long-running services
2. Configure **autoscaling** for App Services based on demand
3. Use **Development tier** for APIM in non-production environments
4. Consider **Azure Container Apps** as an alternative to App Services for better cost efficiency

## Alternative: Using Azure Container Apps

For a more modern, containerized approach:

1. Build Docker images for each service
2. Push to Azure Container Registry
3. Deploy to Azure Container Apps
4. Use built-in service discovery and ingress

This provides better resource utilization and easier scaling.

## Troubleshooting

### Database Connection Issues
- Verify firewall rules allow Azure services
- Check connection string format
- Ensure SSL mode is configured correctly

### Redis Connection Issues
- Verify access keys
- Check SSL configuration
- Ensure port 6380 is allowed

### Identity/Authentication Issues
- Verify redirect URIs are correctly configured
- Check CORS settings
- Ensure HTTPS is enabled

## Next Steps

1. Set up CI/CD pipeline using Azure DevOps or GitHub Actions
2. Configure staging and production environments
3. Implement blue-green deployment strategy
4. Set up automated testing
5. Configure backup and disaster recovery

## Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [Azure Application Gateway Documentation](https://docs.microsoft.com/azure/application-gateway/)
- [Azure Database for PostgreSQL Documentation](https://docs.microsoft.com/azure/postgresql/)
