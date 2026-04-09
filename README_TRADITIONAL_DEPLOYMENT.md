# eShop Reference Application - Traditional Azure Deployment

This version of the eShop reference application has been adapted for traditional Azure deployment using App Services, API Management, and Application Gateway, **without** .NET Aspire dependencies.

## Table of Contents
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [Running the Application](#running-the-application)
- [Azure Deployment](#azure-deployment)
- [Configuration](#configuration)
- [Migration Notes](#migration-notes)

## Architecture

### Local Development
```
APIs & Web Apps (running locally on different ports)
    ?
Infrastructure Services (Docker containers)
- PostgreSQL (with pgvector)
- Redis
- RabbitMQ
```

### Azure Production
```
Internet ? App Gateway (WAF) ? API Management ? App Services
                                                      ?
                                         Azure PaaS Services
                                         - PostgreSQL Flexible Server
                                         - Azure Cache for Redis
                                         - Azure Service Bus
```

See [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md) for detailed Azure architecture and deployment guide.

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) or [VS Code](https://code.visualstudio.com/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (for Azure deployment)

## Local Development Setup

### 1. Start Infrastructure Services

Start PostgreSQL, Redis, and RabbitMQ using Docker Compose:

```bash
docker-compose up -d
```

This will start:
- **PostgreSQL** on port 5432 (with pgvector extension)
- **Redis** on port 6379
- **RabbitMQ** on port 5672 (management UI on port 15672)

Verify services are running:
```bash
docker-compose ps
```

Access RabbitMQ Management UI: http://localhost:15672 (user: guest, password: guest)

### 2. Build the Solution

```bash
dotnet restore
dotnet build
```

### 3. Initialize Databases

The databases will be automatically created and migrated when you first run each service. The EF Core migrations run automatically on startup in development mode.

## Running the Application

### Option 1: Visual Studio

1. Open `eShop.slnx` in Visual Studio 2022
2. Configure multiple startup projects:
   - Identity.API
   - Basket.API
   - Catalog.API
   - Ordering.API
   - Webhooks.API
   - WebApp
   - OrderProcessor (optional)
   - PaymentProcessor (optional)
3. Press F5 to start debugging

### Option 2: Command Line

Open multiple terminal windows and run each service:

**Terminal 1 - Identity Server:**
```bash
cd src/Identity.API
dotnet run
```

**Terminal 2 - Basket API:**
```bash
cd src/Basket.API
dotnet run
```

**Terminal 3 - Catalog API:**
```bash
cd src/Catalog.API
dotnet run
```

**Terminal 4 - Ordering API:**
```bash
cd src/Ordering.API
dotnet run
```

**Terminal 5 - Webhooks API:**
```bash
cd src/Webhooks.API
dotnet run
```

**Terminal 6 - Web App:**
```bash
cd src/WebApp
dotnet run
```

**Terminal 7 - Order Processor (Worker):**
```bash
cd src/OrderProcessor
dotnet run
```

**Terminal 8 - Payment Processor (Worker):**
```bash
cd src/PaymentProcessor
dotnet run
```

### Accessing the Application

- **Web App**: https://localhost:5104
- **Catalog API**: https://localhost:5102/scalar/v1 (API Documentation)
- **Ordering API**: https://localhost:5103/scalar/v1
- **Webhooks API**: https://localhost:5113/scalar/v1
- **Identity Server**: https://localhost:5223

## Azure Deployment

For detailed Azure deployment instructions, see [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md).

Quick overview:
1. Create Azure resources (PostgreSQL, Redis, Service Bus, App Services, APIM)
2. Configure connection strings and app settings
3. Deploy each service to its App Service
4. Configure API Management policies
5. (Optional) Set up Application Gateway with WAF

## Configuration

### Service URLs (Development)

Each service has configured URLs in `appsettings.json`:

**Identity.API**: `http://localhost:5223`
**Basket.API**: `http://localhost:5101`
**Catalog.API**: `http://localhost:5102`
**Ordering.API**: `http://localhost:5103`
**Webhooks.API**: `http://localhost:5113`
**WebApp**: `http://localhost:5104`

### Connection Strings

All services use connection strings from `appsettings.json`. For local development:

```json
{
  "ConnectionStrings": {
    "catalogdb": "Host=localhost;Database=CatalogDB;Username=postgres;Password=postgres",
    "orderingdb": "Host=localhost;Database=OrderingDB;Username=postgres;Password=postgres",
    "identitydb": "Host=localhost;Database=IdentityDB;Username=postgres;Password=postgres",
    "webhooksdb": "Host=localhost;Database=WebhooksDB;Username=postgres;Password=postgres",
    "Redis": "localhost:6379",
    "EventBus": "amqp://localhost"
  }
}
```

### Environment Variables

For Azure deployment, configure these as App Service application settings:

- `ConnectionStrings__catalogdb`
- `ConnectionStrings__orderingdb`
- `ConnectionStrings__identitydb`
- `ConnectionStrings__webhooksdb`
- `ConnectionStrings__Redis`
- `ConnectionStrings__EventBus`
- `Identity__Url`
- `Services__Basket`
- `Services__Catalog`
- `Services__Ordering`

## Migration Notes

This application has been migrated from .NET Aspire to support traditional Azure deployment. Key changes:

### Removed
- ? .NET Aspire service orchestration
- ? Aspire service discovery
- ? Aspire-specific packages (Aspire.StackExchange.Redis, Aspire.Npgsql.*, etc.)
- ? AppHost project (orchestrator)

### Added
- ? Standard .NET packages (StackExchange.Redis, Npgsql, RabbitMQ.Client)
- ? Explicit service URL configuration
- ? Manual service connection setup
- ? Docker Compose for local infrastructure
- ? Azure deployment guide

For detailed migration information, see [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md).

## Project Structure

```
eShop/
??? src/
?   ??? Basket.API/              # Shopping basket gRPC service
?   ??? Catalog.API/             # Product catalog REST API
?   ??? Ordering.API/            # Orders management REST API
?   ??? Identity.API/            # Authentication (IdentityServer)
?   ??? Webhooks.API/            # Webhooks management
?   ??? WebApp/                  # Blazor web frontend
?   ??? OrderProcessor/          # Background worker for order processing
?   ??? PaymentProcessor/        # Background worker for payments
?   ??? WebhookClient/           # Webhooks test client
?   ??? eShop.ServiceDefaults/   # Shared configurations
?   ??? EventBus/                # Event bus abstractions
?   ??? EventBusRabbitMQ/        # RabbitMQ event bus implementation
?   ??? ...
??? tests/
??? docker-compose.yml           # Local infrastructure
??? AZURE_DEPLOYMENT.md          # Azure deployment guide
??? MIGRATION_CHECKLIST.md       # Migration details
```

## Troubleshooting

### Database Connection Issues
```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# View PostgreSQL logs
docker logs eshop-postgres

# Connect to PostgreSQL
docker exec -it eshop-postgres psql -U postgres
```

### Redis Connection Issues
```bash
# Check if Redis is running
docker ps | grep redis

# Test Redis connection
docker exec -it eshop-redis redis-cli ping
```

### RabbitMQ Connection Issues
```bash
# Check if RabbitMQ is running
docker ps | grep rabbitmq

# Access management UI
open http://localhost:15672
```

### Clear All Data
```bash
# Stop and remove containers and volumes
docker-compose down -v

# Restart fresh
docker-compose up -d
```

## Additional Resources

- [Original eShop Documentation](https://github.com/dotnet/eShop)
- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [.NET 10 Documentation](https://docs.microsoft.com/dotnet/)

## Contributing

This is a reference architecture. For the official eShop repository, visit:
https://github.com/dotnet/eShop

## License

This project is licensed under the MIT License.
