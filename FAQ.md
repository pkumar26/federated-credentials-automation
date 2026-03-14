# FAQ & Troubleshooting

Common questions, troubleshooting tips, and operational guides.

## Troubleshooting

### Credential Already Exists

If a credential already exists with the same name, the script will skip it and report it as "Skipped (already exists)".

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

---

## Security Best Practices

1. **Use separate Service Principals** for each environment
2. **Apply least-privilege access** — grant only necessary permissions
3. **Scope SPs to resource groups** rather than the full subscription (see [SETUP.md — Step 1](SETUP.md#step-1-create-service-principals))
4. **Enable environment protection rules** in GitHub (required reviewers, wait timers)
5. **Audit federated credentials** regularly
6. **Use environment-specific secrets** to prevent production access from non-production workflows

---

## Adding a New Repository

1. Add the repo name to the `REPOS` array in `setup_creds.sh` and re-run the script — existing credentials are automatically skipped:
   ```bash
   ./setup_creds.sh
   ```
   Or use `--dynamic` to pick it up automatically if it's already in your GitHub org.

2. Create GitHub environments in the new repo (manually or via `create_repo_env.sh`).

3. If using resource-group scoping, grant the SP access to the new app's resource group:
   ```bash
   az role assignment create --assignee <sp-client-id> \
     --role contributor \
     --scope /subscriptions/{subscription-id}/resourceGroups/{new-app-rg}
   ```
   Repeat for each environment's SP as needed.

---

## Removing a Repository

When decommissioning a repo, clean up its federated credentials from each SP:

1. **List** existing credentials to find the ones to remove:
   ```bash
   az ad app federated-credential list --id <sp-object-id> --query "[].{name:name, subject:subject}" -o table
   ```

2. **Delete** the credentials for the decommissioned repo:
   ```bash
   az ad app federated-credential delete --id <sp-object-id> --federated-credential-id <credential-name>
   ```
   Repeat for each environment's SP (dev, staging, production).

3. If using resource-group scoping and the resource group is also being removed, delete the role assignment:
   ```bash
   az role assignment delete --assignee <sp-client-id> \
     --role contributor \
     --scope /subscriptions/{subscription-id}/resourceGroups/{old-app-rg}
   ```
