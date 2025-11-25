#!/bin/bash

# Configuration
ORG_NAME="your-org-name"
ENVIRONMENTS=("dev" "staging" "production")

# Get list of repositories
REPOS=$(gh repo list $ORG_NAME --limit 1000 --json name --jq '.[].name')

for repo in $REPOS; do
    echo "Setting up environments for $repo..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        # Create environment (this will fail silently if it exists)
        gh api \
            --method PUT \
            -H "Accept: application/vnd.github+json" \
            "/repos/$ORG_NAME/$repo/environments/$env" \
            -f "wait_timer=0" \
            2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✓ Created environment: $env in $repo"
        fi
        
        # Optional: Add protection rules for production
        if [ "$env" == "production" ]; then
            gh api \
                --method PUT \
                -H "Accept: application/vnd.github+json" \
                "/repos/$ORG_NAME/$repo/environments/production" \
                -f "prevent_self_review=true" \
                -F "reviewers[][type]=User" \
                -F "reviewers[][id]=YOUR_USER_ID" \
                2>/dev/null
            
            echo "  ✓ Added protection rules for production"
        fi
    done
done

echo ""
echo "Environment setup complete!"
