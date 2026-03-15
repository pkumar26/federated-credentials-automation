# Setup Guide

![Azure](https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?logo=githubactions&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell_Script-4EAA25?logo=gnubash&logoColor=white)

Full step-by-step instructions for configuring Azure federated credentials with GitHub Actions.

> **Prerequisites** — Make sure you've reviewed the [prerequisites](README.md#prerequisites) before starting.

## Choose Your Identity Type

This repo supports two Azure identity types. Choose one:

| | Service Principal | User-Assigned Managed Identity |
|---|---|---|
| **Azure AD admin required** | Yes (`Application.ReadWrite.All`) | No — just `Contributor` on the resource group |
| **Client secrets can exist** | Yes (even if unused with OIDC) | No — secrets physically cannot be created |
| **IaC support** | Requires AzureAD Terraform provider | First-class Azure resource (Terraform/Bicep/ARM) |
| **Cleanup** | Can become orphaned in Azure AD | Deleting the resource cleans up everything |
| **Script flag** | (default) | `--managed-identity` |

Both approaches use the same GitHub Actions workflow — `azure/login@v2` with `client-id`, `tenant-id`, and `subscription-id`.

---

## Step 1: Create Identities

![Azure CLI](https://img.shields.io/badge/Azure_CLI-0078D4?logo=microsoftazure&logoColor=white)

### Option A: Service Principal (default)

Create a Service Principal for each environment:

```bash
# Create service principals (scoped to specific resource groups — recommended)
az ad sp create-for-rbac --name "github-actions-dev" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{dev-rg-name}

az ad sp create-for-rbac --name "github-actions-staging" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{staging-rg-name}

az ad sp create-for-rbac --name "github-actions-prod" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{prod-rg-name}

# Note the appId (client ID) for each
```

If an SP needs access to **multiple resource groups** (e.g., multiple apps per environment), add role assignments:

```bash
az role assignment create --assignee <sp-client-id> \
  --role contributor \
  --scope /subscriptions/{subscription-id}/resourceGroups/{another-rg-name}
```

Then get the **Object ID** (not Client ID) for each SP:

```bash
az ad sp show --id <appId> --query id -o tsv
```

### Option B: User-Assigned Managed Identity

Create a Managed Identity for each environment in a shared resource group:

```bash
# Create the resource group for identities (if it doesn't exist)
az group create --name infra-rg --location eastus

# Create managed identities
az identity create --name "github-actions-dev" --resource-group infra-rg
az identity create --name "github-actions-staging" --resource-group infra-rg
az identity create --name "github-actions-prod" --resource-group infra-rg
```

Note the `clientId` from each output — you'll need it for GitHub secrets.

Grant each identity access to the resource groups it needs:

```bash
# Get the identity's principal ID
PRINCIPAL_ID=$(az identity show --name "github-actions-dev" --resource-group infra-rg --query principalId -o tsv)

# Assign role
az role assignment create --assignee "$PRINCIPAL_ID" \
  --role contributor \
  --scope /subscriptions/{subscription-id}/resourceGroups/{dev-rg-name}
```

Repeat for each identity and resource group.

### Scoping guidance

> **Why resource-group scoping?** Federated credentials already prevent unauthorized repos/environments from authenticating. Resource-group scoping adds defense in depth — it limits the blast radius if an authorized workflow is ever compromised. For dev/staging environments where risk is lower, subscription-level scoping is also acceptable.

> **Note:** When adding a new application in a new resource group, you must manually grant the identity access to that resource group. The `setup_creds.sh` script only creates federated credentials — it does not manage Azure RBAC role assignments.

## Step 2: Configure the Script

![Shell Script](https://img.shields.io/badge/Shell_Script-4EAA25?logo=gnubash&logoColor=white)

Edit the variables at the top of `setup_creds.sh` (and `create_repo_env.sh` if you plan to use it).

### Organization Name

```bash
ORG_NAME="your-org-name"
```
Replace with your GitHub organization name.

### Environments

```bash
ENVIRONMENTS=("dev" "staging" "production")
```
Define the environments you want to create credentials for. You can add or remove environments as needed.

### If using Service Principal (default)

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

### If using Managed Identity (`--managed-identity`)

```bash
MI_RESOURCE_GROUP="infra-rg"

declare -A MI_NAMES
MI_NAMES["dev"]="github-actions-dev"
MI_NAMES["staging"]="github-actions-staging"
MI_NAMES["production"]="github-actions-prod"
```

Set the resource group where your managed identities live and their names per environment.

### Repository List (manual mode only)

```bash
REPOS=(
    "repo1"
    "repo2"
    "repo3"
    "repo4"
)
```
Add all repository names (without the org prefix) that you want to configure. This list is ignored when using `--dynamic`.

## Step 3: Run the Script

![Bash](https://img.shields.io/badge/Bash-4.0%2B-4EAA25?logo=gnubash&logoColor=white)

```bash
chmod +x setup_creds.sh
```

**Service Principal + manual repo list** (default):

```bash
./setup_creds.sh
```

**Service Principal + dynamic repo discovery** (requires `gh` CLI):

```bash
./setup_creds.sh --dynamic
```

**Managed Identity + manual repo list**:

```bash
./setup_creds.sh --managed-identity
```

**Managed Identity + dynamic repo discovery**:

```bash
./setup_creds.sh --managed-identity --dynamic
```

### What the Script Does

![OIDC](https://img.shields.io/badge/OIDC-OpenID_Connect-orange?logo=openid&logoColor=white)

1. Iterates through each repository (from the hardcoded list or fetched dynamically)
2. For each repository, creates federated credentials for each environment
3. Configures the credentials with:
   - **Issuer:** `https://token.actions.githubusercontent.com`
   - **Subject:** `repo:<org>/<repo>:environment:<env>`
   - **Audience:** `api://AzureADTokenExchange`
4. Provides a summary of created credentials

### Output

The script provides real-time feedback:
- ✓ Successfully created credentials
- ⊘ Skipped (credential already exists)
- ✗ Failed with error details
- Final summary with created / skipped / failed counts

## Step 4: Create GitHub Environments

In each repository, create the environments:
- Go to repository **Settings** → **Environments**
- Create: `dev`, `staging`, `production`

**Automated option:** Use the provided `create_repo_env.sh` script to create environments across all repos in your org:

```bash
chmod +x create_repo_env.sh
# Edit ORG_NAME in the script, then run:
./create_repo_env.sh
```

This script requires `gh` CLI. It also adds protection rules (reviewer requirement) for the `production` environment — set `PROD_REVIEWER_USER_ID` in the script to your GitHub numeric user ID (find it with `gh api /user --jq '.id'`). If left empty, production protection rules are skipped with a warning.

## Step 5: Add GitHub Secrets

Add the following secrets at the **organization level** or **repository level**:

```
AZURE_TENANT_ID=<your-tenant-id>
AZURE_SUBSCRIPTION_ID=<your-subscription-id>

# If using Service Principal — use the appId from az ad sp create-for-rbac output
AZURE_CLIENT_ID_DEV=<dev-sp-appId>
AZURE_CLIENT_ID_STAGING=<staging-sp-appId>
AZURE_CLIENT_ID_PROD=<prod-sp-appId>

# If using Managed Identity — use the clientId from az identity create output
AZURE_CLIENT_ID_DEV=<dev-mi-clientId>
AZURE_CLIENT_ID_STAGING=<staging-mi-clientId>
AZURE_CLIENT_ID_PROD=<prod-mi-clientId>
```

> **Tip:** To retrieve the `clientId` for a Managed Identity: `az identity show --name <name> --resource-group <rg> --query clientId -o tsv`

## Step 6: Use in GitHub Actions Workflow

A complete workflow template is provided in `workflow_template.yml`. It includes:
- Push-triggered deploys to dev
- Manual `workflow_dispatch` with environment selection
- Automatic mapping of environment to the correct client ID secret

Copy it into your repositories:

```bash
cp workflow_template.yml <your-repo>/.github/workflows/deploy.yml
```

Or use the simplified example below as a starting point:

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
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID_DEV }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Deploy to Azure
        run: |
          # Your deployment commands here
          az --version
```
