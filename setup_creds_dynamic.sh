#!/bin/bash

# Configuration
ORG_NAME="your-org-name"
ENVIRONMENTS=("dev" "staging" "production")

# Service Principal Object IDs (get these from Azure Portal or az ad sp show)
declare -A SP_OBJECT_IDS
SP_OBJECT_IDS["dev"]="your-dev-sp-object-id"
SP_OBJECT_IDS["staging"]="your-staging-sp-object-id"
SP_OBJECT_IDS["production"]="your-prod-sp-object-id"

# Get list of repositories (requires GitHub CLI)
echo "Fetching repositories from GitHub org: $ORG_NAME"
REPOS=$(gh repo list $ORG_NAME --limit 1000 --json name --jq '.[].name')

# Counter for tracking
TOTAL=0
CREATED=0

# Create federated credentials
for repo in $REPOS; do
    for env in "${ENVIRONMENTS[@]}"; do
        TOTAL=$((TOTAL + 1))
        
        SUBJECT="repo:${ORG_NAME}/${repo}:environment:${env}"
        DISPLAY_NAME="${repo}-${env}"
        SP_OBJECT_ID="${SP_OBJECT_IDS[$env]}"
        
        echo "Creating credential: $DISPLAY_NAME"
        
        # Create federated credential
        az ad app federated-credential create \
            --id "$SP_OBJECT_ID" \
            --parameters "{
                \"name\": \"${DISPLAY_NAME}\",
                \"issuer\": \"https://token.actions.githubusercontent.com\",
                \"subject\": \"${SUBJECT}\",
                \"audiences\": [\"api://AzureADTokenExchange\"],
                \"description\": \"GitHub Actions for ${repo} ${env} environment\"
            }" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            CREATED=$((CREATED + 1))
            echo "✓ Created: $DISPLAY_NAME"
        else
            echo "✗ Failed or already exists: $DISPLAY_NAME"
        fi
    done
done

echo ""
echo "Summary:"
echo "Total credentials attempted: $TOTAL"
echo "Successfully created: $CREATED"
echo ""
echo "Next steps:"
echo "1. Create GitHub environments (dev, staging, production) in each repo"
echo "2. Add organization secrets for AZURE_CLIENT_ID_* variables"
echo "3. Use the workflow template in your repositories"
