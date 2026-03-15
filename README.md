# Azure Federated Credentials Automation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Azure](https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?logo=githubactions&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell_Script-4EAA25?logo=gnubash&logoColor=white)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/pkumar26/federated-credentials-automation/pulls)

[![GitHub Stars](https://img.shields.io/github/stars/pkumar26/federated-credentials-automation?style=social)](https://github.com/pkumar26/federated-credentials-automation/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/pkumar26/federated-credentials-automation?style=social)](https://github.com/pkumar26/federated-credentials-automation/network/members)
[![GitHub Issues](https://img.shields.io/github/issues/pkumar26/federated-credentials-automation)](https://github.com/pkumar26/federated-credentials-automation/issues)
[![Last Commit](https://img.shields.io/github/last-commit/pkumar26/federated-credentials-automation)](https://github.com/pkumar26/federated-credentials-automation/commits/main)
![Repo Size](https://img.shields.io/github/repo-size/pkumar26/federated-credentials-automation)

This repository provides a set of scripts and templates to automate the creation of Azure AD federated credentials for GitHub Actions workflows across multiple repositories and environments.

## Overview

![Azure AD](https://img.shields.io/badge/Azure_AD-0078D4?logo=microsoftazure&logoColor=white)
![OIDC](https://img.shields.io/badge/OIDC-OpenID_Connect-orange?logo=openid&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?logo=githubactions&logoColor=white)

The scripts create federated credentials that allow GitHub Actions to authenticate with Azure using OpenID Connect (OIDC), eliminating the need for storing Azure secrets in GitHub.

### Why This Works

- **One-time setup:** Scripts handle the bulk creation of credentials
- **No manual maintenance:** Adding a new repo = run script once
- **Centralized control:** Manage 3 identities (Service Principals or Managed Identities) instead of hundreds
- **GitHub environments provide security:** Protection rules, approvals, deployment gates
- **Org-level secrets:** No need to configure secrets per repo

## Repository Structure

| File | Description |
|------|-------------|
| `setup_creds.sh` | Creates federated credentials — supports both **Service Principals** and **User-Assigned Managed Identities**. Uses a hardcoded repo list by default, or pass `--dynamic` to fetch all repos from a GitHub org via `gh` CLI |
| `create_repo_env.sh` | Creates GitHub environments (dev, staging, production) in each repo (requires `gh` CLI) |
| `workflow_template.yml` | Ready-to-use GitHub Actions workflow template with `workflow_dispatch` and environment-to-credential mapping |
| `SETUP.md` | Step-by-step setup guide |
| `FAQ.md` | Troubleshooting, security best practices, adding/removing repositories |

## Prerequisites

![Azure CLI](https://img.shields.io/badge/Azure_CLI-0078D4?logo=microsoftazure&logoColor=white)
![GitHub CLI](https://img.shields.io/badge/GitHub_CLI-181717?logo=github&logoColor=white)

- Azure CLI (`az`) installed and authenticated
- GitHub CLI (`gh`) installed and authenticated — required by `setup_creds.sh --dynamic` and `create_repo_env.sh`
- Appropriate permissions to create Service Principals or Managed Identities and federated credentials in Azure
- GitHub organization with repositories
- Azure subscription ID

## Quick Start

![Shell Script](https://img.shields.io/badge/Shell_Script-4EAA25?logo=gnubash&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4.0%2B-4EAA25?logo=gnubash&logoColor=white)

The script supports two Azure identity types — **Service Principal** (default) and **User-Assigned Managed Identity** (`--managed-identity`). See the [Setup Guide](SETUP.md) for help choosing.

```bash
# 1. Configure the script (edit ORG_NAME, SP_OBJECT_IDS or MI_NAMES, REPOS)
vim setup_creds.sh

# 2. Run with Service Principal (default)
chmod +x setup_creds.sh
./setup_creds.sh

# Or with Managed Identity
./setup_creds.sh --managed-identity

# Add --dynamic to auto-discover all repos in your org
./setup_creds.sh --dynamic
./setup_creds.sh --managed-identity --dynamic
```

For the full walkthrough (creating Service Principals, configuring environments, setting up secrets, and deploying), see the **[Setup Guide](SETUP.md)**.

## Documentation

| Document | Contents |
|----------|----------|
| **[Setup Guide](SETUP.md)** | Choose identity type (SP vs Managed Identity), create identities, configure scripts, set up GitHub environments and secrets, deploy |
| **[FAQ & Troubleshooting](FAQ.md)** | Troubleshooting, security best practices, adding/removing repositories |

## License

This project is licensed under the [MIT License](LICENSE).
