#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
ORG_NAME="your-org-name"
ENVIRONMENTS=("dev" "staging" "production")

# GitHub user ID for production environment reviewer.
# Find your numeric ID: gh api /user --jq '.id'
PROD_REVIEWER_USER_ID=""

# ──────────────────────────────────────────────
# Pre-flight validation
# ──────────────────────────────────────────────
if ! command -v gh >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) is not installed." >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub CLI is not authenticated. Run 'gh auth login'." >&2
    exit 1
fi

if [[ "$ORG_NAME" == "your-org-name" ]]; then
    echo "Error: ORG_NAME is still set to the placeholder value. Edit the script first." >&2
    exit 1
fi

# ──────────────────────────────────────────────
# Fetch repositories and create environments
# ──────────────────────────────────────────────
mapfile -t REPOS < <(gh repo list "$ORG_NAME" --limit 1000 --json name --jq '.[].name')

if [[ ${#REPOS[@]} -eq 0 ]]; then
    echo "Error: No repositories found for org '$ORG_NAME'." >&2
    exit 1
fi

echo "Processing ${#REPOS[@]} repositories"

for repo in "${REPOS[@]}"; do
    echo "Setting up environments for $repo..."

    for env in "${ENVIRONMENTS[@]}"; do
        OUTPUT=$(gh api \
            --method PUT \
            -H "Accept: application/vnd.github+json" \
            "/repos/$ORG_NAME/$repo/environments/$env" \
            -f "wait_timer=0" \
            2>&1) && RC=0 || RC=$?

        if [[ $RC -eq 0 ]]; then
            echo "  ✓ Created environment: $env in $repo"
        else
            echo "  ✗ Failed to create environment: $env in $repo" >&2
            echo "    $OUTPUT" >&2
        fi

        # Add protection rules for production
        if [[ "$env" == "production" ]]; then
            if [[ -z "$PROD_REVIEWER_USER_ID" || "$PROD_REVIEWER_USER_ID" == "YOUR_USER_ID" ]]; then
                echo "  ⊘ Skipping production protection rules (PROD_REVIEWER_USER_ID not configured)"
            else
                PROT_OUTPUT=$(gh api \
                    --method PUT \
                    -H "Accept: application/vnd.github+json" \
                    "/repos/$ORG_NAME/$repo/environments/production" \
                    -f "prevent_self_review=true" \
                    -F "reviewers[][type]=User" \
                    -F "reviewers[][id]=$PROD_REVIEWER_USER_ID" \
                    2>&1) && PROT_RC=0 || PROT_RC=$?

                if [[ $PROT_RC -eq 0 ]]; then
                    echo "  ✓ Added protection rules for production in $repo"
                else
                    echo "  ✗ Failed to add protection rules for production in $repo" >&2
                    echo "    $PROT_OUTPUT" >&2
                fi
            fi
        fi
    done
done

echo ""
echo "Environment setup complete!"
