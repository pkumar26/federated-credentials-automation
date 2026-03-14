# Setup Guide

Full step-by-step instructions for configuring Azure federated credentials with GitHub Actions.

> **Prerequisites** — Make sure you've reviewed the [prerequisites](README.md#prerequisites) before starting.

## Step 1: Create Service Principals

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

> **Why resource-group scoping?** Federated credentials already prevent unauthorized repos/environments from authenticating. Resource-group scoping adds defense in depth — it limits the blast radius if an authorized workflow is ever compromised. For dev/staging environments where risk is lower, subscription-level scoping (`--scopes /subscriptions/{subscription-id}`) is also acceptable.

> **Note:** When adding a new application in a new resource group, you must manually grant the corresponding SP access to that resource group using `az role assignment create` (shown above). The `setup_creds.sh` script only creates federated credentials — it does not manage Azure RBAC role assignments.

**Important:** Save the output from each command. You'll need:
- `appId` (Client ID) — for GitHub secrets
- `appId` — to get the Object ID in the next step

## Step 2: Get Service Principal Object IDs

For each Service Principal, get the Object ID (not the Client ID):

```bash
az ad sp show --id <appId-from-previous-step> --query id -o tsv
```

Run this command for each environment's Service Principal and note the Object IDs.

## Step 3: Configure the Script

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

### Service Principal Object IDs

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

## Step 4: Run the Script

```bash
chmod +x setup_creds.sh
```

**Manual mode** — create credentials for the repos listed in the `REPOS` array:

```bash
./setup_creds.sh
```

**Dynamic mode** — automatically fetch and process **all** repos in your GitHub org (requires `gh` CLI):

```bash
./setup_creds.sh --dynamic
```

### What the Script Does

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

## Step 5: Create GitHub Environments

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

## Step 6: Add GitHub Secrets

Add the following secrets at the **organization level** or **repository level**:

```
AZURE_CLIENT_ID_DEV=<dev-sp-client-id>
AZURE_CLIENT_ID_STAGING=<staging-sp-client-id>
AZURE_CLIENT_ID_PROD=<prod-sp-client-id>
AZURE_TENANT_ID=<your-tenant-id>
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
```

## Step 7: Use in GitHub Actions Workflow

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
