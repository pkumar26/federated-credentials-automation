# Azure Federated Credentials Automation

This repository provides a set of scripts and templates to automate the creation of Azure AD federated credentials for GitHub Actions workflows across multiple repositories and environments.

## Overview

The scripts create federated credentials that allow GitHub Actions to authenticate with Azure using OpenID Connect (OIDC), eliminating the need for storing Azure secrets in GitHub.

### Why This Works

- **One-time setup:** Scripts handle the bulk creation of credentials
- **No manual maintenance:** Adding a new repo = run script once
- **Centralized control:** Manage 3 service principals instead of hundreds
- **GitHub environments provide security:** Protection rules, approvals, deployment gates
- **Org-level secrets:** No need to configure secrets per repo

## Repository Structure

| File | Description |
|------|-------------|
| `setup_creds.sh` | Creates federated credentials — uses a hardcoded repo list by default, or pass `--dynamic` to fetch all repos from a GitHub org via `gh` CLI |
| `create_repo_env.sh` | Creates GitHub environments (dev, staging, production) in each repo (requires `gh` CLI) |
| `workflow_template.yml` | Ready-to-use GitHub Actions workflow template with `workflow_dispatch` and environment-to-credential mapping |
| `SETUP.md` | Step-by-step setup guide |
| `FAQ.md` | Troubleshooting, security best practices, adding/removing repositories |

## Prerequisites

- Azure CLI (`az`) installed and authenticated
- GitHub CLI (`gh`) installed and authenticated — required by `setup_creds.sh --dynamic` and `create_repo_env.sh`
- Appropriate permissions to create Service Principals and federated credentials in Azure AD
- GitHub organization with repositories
- Azure subscription ID

## Quick Start

```bash
# 1. Configure the script (edit ORG_NAME, SP_OBJECT_IDS, REPOS)
vim setup_creds.sh

# 2. Run it
chmod +x setup_creds.sh
./setup_creds.sh

# Or use --dynamic to auto-discover all repos in your org
./setup_creds.sh --dynamic
```

For the full walkthrough (creating Service Principals, configuring environments, setting up secrets, and deploying), see the **[Setup Guide](SETUP.md)**.

## Documentation

| Document | Contents |
|----------|----------|
| **[Setup Guide](SETUP.md)** | Step-by-step instructions: create SPs, configure scripts, run them, set up GitHub environments and secrets, deploy |
| **[FAQ & Troubleshooting](FAQ.md)** | Troubleshooting, security best practices, adding/removing repositories |

## License

This project is licensed under the [MIT License](LICENSE).
