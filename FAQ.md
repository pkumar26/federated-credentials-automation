# FAQ & Troubleshooting

![Azure](https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=white)

Common questions, troubleshooting tips, and operational guides.

## Troubleshooting

![Azure CLI](https://img.shields.io/badge/Azure_CLI-0078D4?logo=microsoftazure&logoColor=white)
![GitHub CLI](https://img.shields.io/badge/GitHub_CLI-181717?logo=github&logoColor=white)

### Personal vs Organization Accounts

This project supports both GitHub organizations and personal accounts.

**Personal accounts — key differences:**
- Set `GITHUB_OWNER` to your **GitHub username** (not an org name)
- Secrets are set **per repository** instead of at the organization level
- Environment protection rules (required reviewers, wait timers) require **GitHub Pro** for private repos — on free personal accounts, environments are created but protection rules are skipped
- The notebooks auto-detect your account type and adjust behavior accordingly
- `gh repo list <username>` works for discovering personal repos (same as for orgs)

### Identity Already Exists

If an Azure identity (Service Principal or Managed Identity) already exists when running notebook 01, the notebook detects it and reuses the existing identity instead of failing. You'll see:
```
⊘ SP 'github-actions-dev' already exists — reusing it.
```
or
```
⊘ Identity 'github-actions-dev' already exists — reusing it.
```

This is safe — the existing identity's client ID and object ID are captured for use by subsequent notebooks.

### Credential Already Exists

If a federated credential already exists with the same name, the script will skip it and report it as "Skipped (already exists)".

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

For GitHub CLI:
```bash
gh auth status
```

### Secret Not Found in GitHub Actions

If your workflow fails with errors about missing secrets (e.g., `AZURE_CLIENT_ID_DEV` is empty):

1. **Organization accounts:** Verify org-level secrets exist: `gh secret list --org <org-name>`
2. **Personal accounts:** Verify repo-level secrets exist: `gh secret list --repo <username>/<repo>`
3. **Common cause:** Secrets were set at the org level but you're using a personal account (or vice versa). The notebooks auto-detect account type, but if you ran `gh secret set --org` on a personal account, the command would have failed silently.
4. **Fix:** Re-run notebook 04 or manually set secrets at the correct level.

---

## Security Best Practices

![Security](https://img.shields.io/badge/Security-Best_Practices-critical?logo=shieldsdotio&logoColor=white)

1. **Use separate identities per environment** — one Service Principal or Managed Identity per environment (dev, staging, production)
2. **Apply least-privilege access** — grant only necessary permissions
3. **Scope identities to resource groups** rather than the full subscription (see [SETUP.md — Step 1](SETUP.md#step-1-create-identities))
4. **Enable environment protection rules** in GitHub (required reviewers, wait timers)
5. **Audit federated credentials** regularly
6. **Use environment-specific secrets** to prevent production access from non-production workflows

---

## Adding a New Repository

![Azure CLI](https://img.shields.io/badge/Azure_CLI-0078D4?logo=microsoftazure&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell_Script-4EAA25?logo=gnubash&logoColor=white)

1. Add the repo name to the `REPOS` array in `setup_creds.sh` and re-run the script — existing credentials are automatically skipped:
   ```bash
   ./setup_creds.sh
   ```
   Or use `--dynamic` to pick it up automatically if it's already in your GitHub org.

2. Create GitHub environments in the new repo (manually or via `create_repo_env.sh`).

3. If using resource-group scoping, grant the identity access to the new app's resource group:
   ```bash
   # Service Principal
   az role assignment create --assignee <sp-client-id> \
     --role contributor \
     --scope /subscriptions/{subscription-id}/resourceGroups/{new-app-rg}

   # Managed Identity
   PRINCIPAL_ID=$(az identity show --name <identity-name> --resource-group <infra-rg> --query principalId -o tsv)
   az role assignment create --assignee "$PRINCIPAL_ID" \
     --role contributor \
     --scope /subscriptions/{subscription-id}/resourceGroups/{new-app-rg}
   ```
   Repeat for each environment's identity as needed.

---

## Removing a Repository

![Azure CLI](https://img.shields.io/badge/Azure_CLI-0078D4?logo=microsoftazure&logoColor=white)

When decommissioning a repo, clean up its federated credentials:

### Service Principal

1. **List** existing credentials:
   ```bash
   az ad app federated-credential list --id <sp-object-id> --query "[].{name:name, subject:subject}" -o table
   ```

2. **Delete** the credentials for the decommissioned repo:
   ```bash
   az ad app federated-credential delete --id <sp-object-id> --federated-credential-id <credential-name>
   ```
   Repeat for each environment's SP (dev, staging, production).

### Managed Identity

1. **List** existing credentials:
   ```bash
   az identity federated-credential list --identity-name <identity-name> --resource-group <infra-rg> --query "[].{name:name, subject:subject}" -o table
   ```

2. **Delete** the credentials for the decommissioned repo:
   ```bash
   az identity federated-credential delete --identity-name <identity-name> --resource-group <infra-rg> --name <credential-name>
   ```
   Repeat for each environment's identity.

### Cleanup role assignments

If using resource-group scoping and the resource group is also being removed:
```bash
az role assignment delete --assignee <client-or-principal-id> \
  --role contributor \
  --scope /subscriptions/{subscription-id}/resourceGroups/{old-app-rg}
```
