# Azure Federated Credentials Setup Script

This script automates the creation of Azure AD federated credentials for GitHub Actions workflows across multiple repositories and environments.

## Overview

The script creates federated credentials that allow GitHub Actions to authenticate with Azure using OpenID Connect (OIDC), eliminating the need for storing Azure secrets in GitHub.

### Why This Works

- **One-time setup:** Scripts handle the bulk creation of credentials
- **No manual maintenance:** Adding a new repo = run script once
- **Centralized control:** Manage 3 service principals instead of hundreds
- **GitHub environments provide security:** Protection rules, approvals, deployment gates
- **Org-level secrets:** No need to configure secrets per repo

## Prerequisites

- Azure CLI (`az`) installed and authenticated
- GitHub CLI (`gh`) installed and authenticated - if using *dynamic script
- Appropriate permissions to create Service Principals and federated credentials in Azure AD
- GitHub organization with repositories
- Azure subscription ID

## Setup Steps

### Step 1: Create Service Principals

Before running the script, create Service Principals for each environment:

```bash
# Create service principals
az ad sp create-for-rbac --name "github-actions-dev" --role contributor --scopes /subscriptions/{subscription-id}
az ad sp create-for-rbac --name "github-actions-staging" --role contributor --scopes /subscriptions/{subscription-id}
az ad sp create-for-rbac --name "github-actions-prod" --role contributor --scopes /subscriptions/{subscription-id}

# Note the appId (client ID) for each
```

**Important:** Save the output from each command. You'll need:
- `appId` (Client ID) - for GitHub secrets
- `appId` - to get the Object ID in the next step

### Step 2: Get Service Principal Object IDs

For each Service Principal, get the Object ID (not the Client ID):

```bash
az ad sp show --id <appId-from-previous-step> --query id -o tsv
```

Run this command for each environment's Service Principal and note the Object IDs.

### Step 3: Configure the Script

## Configuration

### 1. Organization Name

```bash
ORG_NAME="your-org-name"
```
Replace with your GitHub organization name.

### 2. Environments

```bash
ENVIRONMENTS=("dev" "staging" "production")
```
Define the environments you want to create credentials for. You can add or remove environments as needed.

### 3. Service Principal Object IDs

```bash
declare -A SP_OBJECT_IDS
SP_OBJECT_IDS["dev"]="your-dev-sp-object-id"
SP_OBJECT_IDS["staging"]="your-staging-sp-object-id"
SP_OBJECT_IDS["production"]="your-prod-sp-object-id"
```

Get the Object IDs for your Service Principals:
```bash
az ad sp show --id <client-id> --query id -o tsv
```

### 4. Repository List

```bash
REPOS=(
    "repo1"
    "repo2"
    "repo3"
    "repo4"
)
```
Add all repository names (without the org prefix) that you want to configure.

## Usage

1. **Make the script executable:**
   ```bash
   chmod +x script.sh
   ```

2. **Run the script:**
   ```bash
   ./script.sh
   ```

## What the Script Does

1. Iterates through each repository in the `REPOS` array
2. For each repository, creates federated credentials for each environment
3. Configures the credentials with:
   - **Issuer:** `https://token.actions.githubusercontent.com`
   - **Subject:** `repo:<org>/<repo>:environment:<env>`
   - **Audience:** `api://AzureADTokenExchange`
4. Provides a summary of created credentials

## Output

The script provides real-time feedback:
- ✓ Successfully created credentials
- ✗ Failed or already existing credentials
- Final summary with counts

## Next Steps After Running the Script

### 1. Create GitHub Environments

In each repository, create the environments:
- Go to repository **Settings** → **Environments**
- Create: `dev`, `staging`, `production`

**Note:** This step can be automated using the GitHub CLI or API. A reference script for automating environment creation is provided in the repository.

### 2. Add GitHub Secrets

Add the following secrets at the **organization level** or **repository level**:

```
AZURE_CLIENT_ID_DEV=<dev-sp-client-id>
AZURE_CLIENT_ID_STAGING=<staging-sp-client-id>
AZURE_CLIENT_ID_PRODUCTION=<prod-sp-client-id>
AZURE_TENANT_ID=<your-tenant-id>
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
```

### 3. Use in GitHub Actions Workflow

Example workflow file (`.github/workflows/deploy.yml`):

```yaml
name: Deploy to Azure

on:
  push:
    branches: [main]

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    environment: dev
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID_DEV }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Deploy to Azure
        run: |
          # Your deployment commands here
          az --version
```

## Troubleshooting

### Credential Already Exists
If a credential already exists with the same name, the script will skip it and report as "Failed or already exists".

### Permission Errors
Ensure you have the following Azure AD permissions:
- `Application.ReadWrite.All` or
- Owner/Contributor role on the Service Principal

### Authentication Issues
Make sure you're logged into Azure CLI:
```bash
az login
az account show
```

## Security Best Practices

1. **Use separate Service Principals** for each environment
2. **Apply least-privilege access** - grant only necessary permissions
3. **Enable environment protection rules** in GitHub (required reviewers, wait timers)
4. **Audit federated credentials** regularly
5. **Use environment-specific secrets** to prevent production access from non-production workflows

## Adding a New Repository

If you need to add credentials for a new repository without re-running the entire script, you can use this quick command:

```bash
# Configuration
ORG_NAME="your-org-name"
REPO_NAME="new-repo"

# Service Principal Object IDs
declare -A SP_OBJECT_IDS
SP_OBJECT_IDS["dev"]="your-dev-sp-object-id"
SP_OBJECT_IDS["staging"]="your-staging-sp-object-id"
SP_OBJECT_IDS["production"]="your-prod-sp-object-id"

# Create credentials for all environments
for env in dev staging production; do
    SUBJECT="repo:${ORG_NAME}/${REPO_NAME}:environment:${env}"
    DISPLAY_NAME="${REPO_NAME}-${env}"
    SP_OBJECT_ID="${SP_OBJECT_IDS[$env]}"
    
    echo "Creating credential: $DISPLAY_NAME"
    
    az ad app federated-credential create \
        --id "$SP_OBJECT_ID" \
        --parameters "{
            \"name\": \"${DISPLAY_NAME}\",
            \"issuer\": \"https://token.actions.githubusercontent.com\",
            \"subject\": \"${SUBJECT}\",
            \"audiences\": [\"api://AzureADTokenExchange\"],
            \"description\": \"GitHub Actions for ${REPO_NAME} ${env} environment\"
        }"
    
    echo "✓ Created: $DISPLAY_NAME"
done
```

**Don't forget to:**
1. Update `ORG_NAME` and `REPO_NAME`
2. Update the Service Principal Object IDs
3. Create the corresponding GitHub environments in the new repository

## Cleaning Up

To delete federated credentials:

```bash
az ad app federated-credential delete \
    --id <sp-object-id> \
    --federated-credential-id <credential-name>
```

Or list all credentials first:
```bash
az ad app federated-credential list --id <sp-object-id>
```

## References

- [Azure Federated Identity Credentials](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
- [GitHub Actions OIDC with Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure Login Action](https://github.com/Azure/login)

## License

This script is provided as-is for automation purposes.
