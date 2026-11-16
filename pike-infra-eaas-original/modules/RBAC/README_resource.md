# 🎯 RBAC — Resource scope

Assigns an Azure role to an existing principal on an existing Azure Storage Account. This template is available for direct deployment but is **not currently wired into the GitHub Actions RBAC workflow**.

> **Scope note:** Bicep requires the target resource's resource type and API version at compile time. This implementation uses `Microsoft.Storage/storageAccounts@2023-05-01`. For another resource type, add a matching typed existing-resource declaration (or a dedicated resource-scope template) rather than passing an arbitrary resource ID as a deployment scope.

## 1. Inputs

| Input | Type | Required | Example / allowed values | Purpose |
|---|---|---:|---|---|
| `storageAccountName` | string | Yes | `stexample001` | Name of the existing Storage Account in the deployment resource group |
| `principalId` | string | Yes | Entra object ID GUID | Existing user, group, or service principal receiving access |
| `roleDefinitionGuid` | string | Yes | Reader: `acdd72a7-3385-48ef-bd42-f606fba81ae7` | Built-in or custom role definition GUID |
| `principalType` | string | No | `User`, `Group`, `ServicePrincipal` (default: `User`) | Principal type passed to Azure |

## 2. How the template generates the assignment

1. The deployment runs at resource-group scope; `storageAccountName` identifies an existing Storage Account in that resource group.
2. The typed `existing` declaration resolves the target Storage Account resource ID.
3. `subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)` constructs the role-definition resource ID.
4. `guid(targetStorageAccount.id, principalId, roleDefinitionId)` generates a deterministic role-assignment name.
5. The `Microsoft.Authorization/roleAssignments@2022-04-01` resource is deployed with its scope set to the existing Storage Account.

## 3. Outputs

| Output | Type | Generated from | Meaning |
|---|---|---|---|
| `roleAssignmentId` | string | `roleAssignment.id` | Full Azure resource ID of the role assignment |
| `assignedResourceId` | string | `targetStorageAccount.id` | Full Azure resource ID of the Storage Account receiving access |

The template does not output the principal's display name or the role's display name. Retrieve those separately if they are needed in a report.

## 4. What is created

- One `Microsoft.Authorization/roleAssignments` resource scoped to the existing Storage Account.
- The Storage Account and Entra principal are references; neither is created by this template.
- The deterministic GUID makes repeated deployments of the same principal/role/scope converge on the same role-assignment resource name.

## 5. Deployment example

```powershell
az deployment group what-if --resource-group "<RESOURCE_GROUP>" --template-file modules/RBAC/RBAC_resource.bicep --parameters storageAccountName="<STORAGE_ACCOUNT>" principalId="<OBJECT_ID>" roleDefinitionGuid="acdd72a7-3385-48ef-bd42-f606fba81ae7" principalType="User"

az deployment group create --name "rbac-resource" --resource-group "<RESOURCE_GROUP>" --template-file modules/RBAC/RBAC_resource.bicep --parameters storageAccountName="<STORAGE_ACCOUNT>" principalId="<OBJECT_ID>" roleDefinitionGuid="acdd72a7-3385-48ef-bd42-f606fba81ae7" principalType="User"
```

The example GUID is the built-in **Reader** role.

## 6. Prerequisites and limitations

- The Storage Account and Entra principal must already exist.
- The deploying identity must be allowed to create role assignments at the resource scope.
- This module does not create managed groups, users, or identities.
- This template is Storage Account-specific. It is not a generic resource-scope implementation for VMs, Key Vaults, SQL databases, or all Azure resource types.
- It is not currently invoked by `deploy.yml`; only resource-group access is automated today.

## 7. Expected deployment result

A successful deployment creates or confirms the Storage Account role assignment and exposes `roleAssignmentId` and `assignedResourceId` as deployment outputs. Review What-If before applying.
