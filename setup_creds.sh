#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
ORG_NAME="your-org-name"
ENVIRONMENTS=("dev" "staging" "production")

# Service Principal Object IDs (get these from Azure Portal or az ad sp show)
declare -A SP_OBJECT_IDS
SP_OBJECT_IDS["dev"]="your-dev-sp-object-id"
SP_OBJECT_IDS["staging"]="your-staging-sp-object-id"
SP_OBJECT_IDS["production"]="your-prod-sp-object-id"

# Manual list of repositories (used when --dynamic is not passed)
# Add your repository names here (one per line)
REPOS=(
    "repo1"
    "repo2"
    "repo3"
    "repo4"
)

# ──────────────────────────────────────────────
# Parse flags
# ──────────────────────────────────────────────
DYNAMIC=false
for arg in "$@"; do
    case "$arg" in
        --dynamic) DYNAMIC=true ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# ──────────────────────────────────────────────
# Pre-flight validation
# ──────────────────────────────────────────────
if ! command -v az >/dev/null 2>&1; then
    echo "Error: Azure CLI (az) is not installed." >&2
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo "Error: Azure CLI is not authenticated. Run 'az login'." >&2
    exit 1
fi

if [[ "$ORG_NAME" == "your-org-name" ]]; then
    echo "Error: ORG_NAME is still set to the placeholder value. Edit the script first." >&2
    exit 1
fi

for env in "${ENVIRONMENTS[@]}"; do
    if [[ "${SP_OBJECT_IDS[$env]}" == your-*-sp-object-id ]]; then
        echo "Error: SP_OBJECT_IDS[$env] is still set to the placeholder value. Edit the script first." >&2
        exit 1
    fi
done

if [[ "$DYNAMIC" == true ]]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: GitHub CLI (gh) is not installed. Required for --dynamic mode." >&2
        exit 1
    fi
    if ! gh auth status >/dev/null 2>&1; then
        echo "Error: GitHub CLI is not authenticated. Run 'gh auth login'." >&2
        exit 1
    fi
fi

# ──────────────────────────────────────────────
# Build repo list
# ──────────────────────────────────────────────
if [[ "$DYNAMIC" == true ]]; then
    echo "Fetching repositories from GitHub org: $ORG_NAME"
    mapfile -t REPOS < <(gh repo list "$ORG_NAME" --limit 1000 --json name --jq '.[].name')
    if [[ ${#REPOS[@]} -eq 0 ]]; then
        echo "Error: No repositories found for org '$ORG_NAME'." >&2
        exit 1
    fi
fi

echo "Processing ${#REPOS[@]} repositories"

# ──────────────────────────────────────────────
# Create federated credentials
# ──────────────────────────────────────────────
TOTAL=0
CREATED=0
SKIPPED=0
FAILED=0

for repo in "${REPOS[@]}"; do
    for env in "${ENVIRONMENTS[@]}"; do
        TOTAL=$((TOTAL + 1))

        SUBJECT="repo:${ORG_NAME}/${repo}:environment:${env}"
        DISPLAY_NAME="${repo}-${env}"
        SP_OBJECT_ID="${SP_OBJECT_IDS[$env]}"

        echo "Creating credential: $DISPLAY_NAME"

        OUTPUT=$(az ad app federated-credential create \
            --id "$SP_OBJECT_ID" \
            --parameters "{
                \"name\": \"${DISPLAY_NAME}\",
                \"issuer\": \"https://token.actions.githubusercontent.com\",
                \"subject\": \"${SUBJECT}\",
                \"audiences\": [\"api://AzureADTokenExchange\"],
                \"description\": \"GitHub Actions for ${repo} ${env} environment\"
            }" 2>&1) && RC=0 || RC=$?

        if [[ $RC -eq 0 ]]; then
            CREATED=$((CREATED + 1))
            echo "  ✓ Created: $DISPLAY_NAME"
        elif echo "$OUTPUT" | grep -qi "already exists"; then
            SKIPPED=$((SKIPPED + 1))
            echo "  ⊘ Skipped (already exists): $DISPLAY_NAME"
        else
            FAILED=$((FAILED + 1))
            echo "  ✗ Failed: $DISPLAY_NAME" >&2
            echo "    $OUTPUT" >&2
        fi
    done
done

echo ""
echo "Summary:"
echo "  Total attempted: $TOTAL"
echo "  Created:         $CREATED"
echo "  Skipped:         $SKIPPED"
echo "  Failed:          $FAILED"
echo ""
echo "Next steps:"
echo "  1. Create GitHub environments (dev, staging, production) in each repo"
echo "  2. Add organization secrets for AZURE_CLIENT_ID_* variables"
echo "  3. Use the workflow template in your repositories"
