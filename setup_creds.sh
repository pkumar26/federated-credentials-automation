#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
# GitHub owner — organization name OR personal username.
# For personal accounts, set this to your GitHub username.
GITHUB_OWNER="your-org-or-username"
ENVIRONMENTS=("dev" "staging" "production")

# ── Option A: Service Principal (default) ─────
# Get Object IDs via: az ad sp show --id <client-id> --query id -o tsv
declare -A SP_OBJECT_IDS
SP_OBJECT_IDS["dev"]="your-dev-sp-object-id"
SP_OBJECT_IDS["staging"]="your-staging-sp-object-id"
SP_OBJECT_IDS["production"]="your-prod-sp-object-id"

# ── Option B: Managed Identity (--managed-identity) ──
# Resource group where managed identities are created
MI_RESOURCE_GROUP="your-infra-rg"
# Identity names per environment
declare -A MI_NAMES
MI_NAMES["dev"]="github-actions-dev"
MI_NAMES["staging"]="github-actions-staging"
MI_NAMES["production"]="github-actions-prod"

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
USE_MI=false
for arg in "$@"; do
    case "$arg" in
        --dynamic) DYNAMIC=true ;;
        --managed-identity) USE_MI=true ;;
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

if [[ "$GITHUB_OWNER" == "your-org-or-username" ]]; then
    echo "Error: GITHUB_OWNER is still set to the placeholder value. Edit the script first." >&2
    exit 1
fi

if [[ "$USE_MI" == true ]]; then
    if [[ "$MI_RESOURCE_GROUP" == "your-infra-rg" ]]; then
        echo "Error: MI_RESOURCE_GROUP is still set to the placeholder value. Edit the script first." >&2
        exit 1
    fi
    for env in "${ENVIRONMENTS[@]}"; do
        if [[ "${MI_NAMES[$env]}" == "" ]]; then
            echo "Error: MI_NAMES[$env] is not set. Edit the script first." >&2
            exit 1
        fi
    done
    echo "Mode: Managed Identity"
else
    for env in "${ENVIRONMENTS[@]}"; do
        if [[ "${SP_OBJECT_IDS[$env]}" == your-*-sp-object-id ]]; then
            echo "Error: SP_OBJECT_IDS[$env] is still set to the placeholder value. Edit the script first." >&2
            exit 1
        fi
    done
    echo "Mode: Service Principal"
fi

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
    echo "Fetching repositories from GitHub: $GITHUB_OWNER"
    mapfile -t REPOS < <(gh repo list "$GITHUB_OWNER" --limit 1000 --json name --jq '.[].name')
    if [[ ${#REPOS[@]} -eq 0 ]]; then
        echo "Error: No repositories found for '$GITHUB_OWNER'." >&2
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

        SUBJECT="repo:${GITHUB_OWNER}/${repo}:environment:${env}"
        DISPLAY_NAME="${repo}-${env}"

        echo "Creating credential: $DISPLAY_NAME"

        if [[ "$USE_MI" == true ]]; then
            OUTPUT=$(az identity federated-credential create \
                --identity-name "${MI_NAMES[$env]}" \
                --resource-group "$MI_RESOURCE_GROUP" \
                --name "$DISPLAY_NAME" \
                --issuer "https://token.actions.githubusercontent.com" \
                --subject "$SUBJECT" \
                --audiences "api://AzureADTokenExchange" \
                2>&1) && RC=0 || RC=$?
        else
            SP_OBJECT_ID="${SP_OBJECT_IDS[$env]}"
            OUTPUT=$(az ad app federated-credential create \
                --id "$SP_OBJECT_ID" \
                --parameters "{
                    \"name\": \"${DISPLAY_NAME}\",
                    \"issuer\": \"https://token.actions.githubusercontent.com\",
                    \"subject\": \"${SUBJECT}\",
                    \"audiences\": [\"api://AzureADTokenExchange\"],
                    \"description\": \"GitHub Actions for ${repo} ${env} environment\"
                }" 2>&1) && RC=0 || RC=$?
        fi

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
echo "  2. Add GitHub secrets for AZURE_CLIENT_ID_* (org-level or repo-level)"
echo "  3. Use the workflow template in your repositories"
