using './main.bicep'

// ─── Required parameters ──────────────────────────────────────────────────────
// Set POSTGRES_ADMIN_PASSWORD environment variable before deploying:
//   export POSTGRES_ADMIN_PASSWORD='<YourStrongPassword>'
//   az deployment group create \
//     --resource-group rg-eshop \
//     --template-file infra/main.bicep \
//     --parameters infra/main.bicepparam \
//     --parameters postgresAdminPassword=$POSTGRES_ADMIN_PASSWORD

param postgresAdminPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD')

// ─── Optional overrides ───────────────────────────────────────────────────────

param namePrefix = 'eshop'

param location = 'eastus'

param postgresAdminUser = 'eshopadmin'

param tags = {
  application: 'eShop'
  environment: 'production'
  managedBy: 'bicep'
}
