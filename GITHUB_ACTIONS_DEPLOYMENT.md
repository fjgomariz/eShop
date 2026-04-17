# GitHub Actions Deployment To Existing Azure Resources

This repository includes a manual workflow that deploys the application code to Azure resources that were already provisioned with Bicep.

Workflow file:
- `.github/workflows/deploy-existing-azure.yml`

## What This Workflow Does

When started manually, it:
1. Logs in to Azure using OpenID Connect (OIDC).
2. Restores the solution.
3. Publishes each deployable project.
4. Packages each app as a zip.
5. Deploys each package to its corresponding existing App Service.

Target App Service name format:
- `<name_prefix>-identity-api`
- `<name_prefix>-catalog-api`
- `<name_prefix>-basket-api`
- `<name_prefix>-ordering-api`
- `<name_prefix>-webhooks-api`
- `<name_prefix>-webapp`
- `<name_prefix>-webhookclient`
- `<name_prefix>-orderprocessor`
- `<name_prefix>-paymentprocessor`

This aligns with `infra/main.bicep` naming.

## Required GitHub Secrets

Add these repository secrets:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

These are used by `azure/login@v2`.

## Create The OIDC Identity In Azure (One-Time Setup)

Use these steps to create the Microsoft Entra application and federated credential required for GitHub OIDC login.

### 1. Define values

Set values for your repo and target resource group:

```bash
APP_NAME="eshop-github-actions-oidc"
RESOURCE_GROUP="rg-eshop"
GITHUB_OWNER="<your-github-org-or-user>"
GITHUB_REPO="eShop"
```

Get subscription and tenant from your current Azure account:

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
```

### 2. Create app registration and service principal

```bash
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
az ad sp create --id "$APP_ID"
APP_OBJECT_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)
```

### 3. Add federated credential for GitHub Actions

For manual runs from the `main` branch, create this credential:

```bash
cat > federated-main.json <<EOF
{
   "name": "github-main",
   "issuer": "https://token.actions.githubusercontent.com",
   "subject": "repo:${GITHUB_OWNER}/${GITHUB_REPO}:ref:refs/heads/main",
   "audiences": ["api://AzureADTokenExchange"]
}
EOF

az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters @federated-main.json
```

If you use GitHub Environments instead (for example `production`), use this subject format:

```text
repo:<owner>/<repo>:environment:production
```

### 4. Grant Azure RBAC on the target scope

Grant deployment rights on the resource group where the App Services already exist:

```bash
az role assignment create \
   --assignee "$APP_ID" \
   --role Contributor \
   --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
```

For stricter least privilege, replace `Contributor` with narrower roles and/or assign at individual app scope.

### 5. Add GitHub repository secrets from created identity

Set these values in GitHub repository secrets:
- `AZURE_CLIENT_ID` = `APP_ID`
- `AZURE_TENANT_ID` = `TENANT_ID`
- `AZURE_SUBSCRIPTION_ID` = `SUBSCRIPTION_ID`

Then the workflow can authenticate with OIDC and deploy without storing a client secret.

## Required Workflow Inputs

The workflow asks for:
- `resource_group`: Resource group where App Services were created.
- `name_prefix`: Same prefix used in Bicep (for example `eshop-frgom`).

## How To Create Secrets In GitHub

1. Open your repository in GitHub.
2. Go to **Settings** > **Secrets and variables** > **Actions**.
3. Select **New repository secret**.
4. Create each required secret name and value:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`

## How To Create Variables In GitHub (Optional)

If you want to avoid typing inputs each run, create repository variables and later reference them in the workflow.

1. Open **Settings** > **Secrets and variables** > **Actions**.
2. Open the **Variables** tab.
3. Select **New repository variable**.
4. Example variables:
   - `AZURE_RESOURCE_GROUP` = `rg-eshop`
   - `ESHOP_NAME_PREFIX` = `eshop-frgom`

## Optional: Use GitHub Environment Secrets

For stronger control, you can use environment-level secrets:

1. Open **Settings** > **Environments**.
2. Create an environment (for example `production`).
3. Add the same Azure secrets in that environment.
4. Update the workflow job with `environment: production`.

## How To Run The Workflow

1. Open the **Actions** tab in GitHub.
2. Select **Deploy To Existing Azure Resources**.
3. Select **Run workflow**.
4. Provide:
   - `resource_group` (for example `rg-eshop`)
   - `name_prefix` (for example `eshop-frgom`)
5. Run and monitor the deployment logs.

## Notes

- This workflow deploys application code only. It does not provision Azure infrastructure.
- Provisioning remains managed by Bicep (`infra/main.bicep`).
- Ensure the app names generated from `name_prefix` already exist in Azure before running.
