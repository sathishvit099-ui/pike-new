# 🏷️ RBAC — Resource-group scope

Assigns an Azure role on an existing resource group. The template is subscription-scoped so it can target the requested resource group by name. This is the **only RBAC scope currently wired into the repository's GitHub Actions workflow**.

## 1. Inputs

### Bicep template parameters

| Input | Type | Required | Example / allowed values | Purpose |
|---|---|---:|---|---|
| `resourceGroupName` | string | Yes | `rg-example-dev-001` | Existing resource group receiving the role assignment |
| `principalId` | string | Yes | Entra object ID GUID | Existing principal receiving access |
| `roleDefinitionGuid` | string | Yes | Reader: `acdd72a7-3385-48ef-bd42-f606fba81ae7` | Role definition to assign |
| `principalType` | string | No | `User`, `Group`, `ServicePrincipal` (default: `User`) | Principal type passed to Azure |

### Workflow / `input.json` fields

The current `deploy-rbac` job reads each object in `rbac.resourceGroupAccess[]`:

| JSON field | Required | Example | How it is used |
|---|---:|---|---|
| `resourceGroupName` | Yes | `rg-example-dev-001` | Must match exactly one `landingZones.resourceGroups[].rgName`; that match validates the requested target |
| `principalEmail` | Yes | `user@contoso.com` | Passed to `az ad user show --id` to resolve the user's Entra object ID |
| `principalType` | Yes in current input | `User` | Passed to the Bicep template |
| `roleDefinitionName` | Documentation / human-readable input | `Reader` | Describes the requested role; the current workflow does not resolve or validate this name |
| `roleDefinitionGuid` | Yes | `acdd72a7-3385-48ef-bd42-f606fba81ae7` | Passed to the Bicep template as the authoritative role ID |

**Important:** The workflow currently resolves only user principals using `az ad user show`. Although the Bicep template accepts `User`, `Group`, and `ServicePrincipal`, the workflow does not yet resolve group or service-principal identifiers from their names/emails. For those types, the workflow needs separate lookup logic before they can be automated.

## 2. How the workflow and template generate the assignment

1. GitHub Actions checks out the branch and authenticates to Azure using `azure/login@v2` and OIDC.
2. The job reads `input.json` and iterates through `rbac.resourceGroupAccess[]`.
3. It validates that `resourceGroupName` matches exactly one resource group in `landingZones.resourceGroups[]`.
4. It resolves `principalEmail` to an Entra object ID using `az ad user show --id ... --query id -o tsv`.
5. PowerShell creates a temporary ARM deployment parameters file under `$env:RUNNER_TEMP`. The file contains `resourceGroupName`, resolved `principalId`, `roleDefinitionGuid`, and `principalType`.
6. The workflow runs subscription-scope What-If using `RBAC_resource_group.bicep`, then deploys it if What-If succeeds.
7. In Bicep, `targetResourceGroup.id` identifies the existing resource group. `subscriptionResourceId(...)` builds the role-definition ID. `guid(targetResourceGroup.id, principalId, roleDefinitionId)` generates a deterministic role-assignment name.
8. Azure creates the role assignment at `targetResourceGroup` scope.

## 3. Outputs

| Output | Type | Generated from | Meaning |
|---|---|---|---|
| `roleAssignmentId` | string | `roleAssignment.id` | Full Azure resource ID of the role assignment |
| `assignedResourceGroupId` | string | `targetResourceGroup.id` | Full Azure resource ID of the resource group receiving access |

The workflow currently prints the deployment output in Azure CLI's table format but does not separately parse and publish these values as a custom summary artifact. Add explicit output capture/reporting if a consolidated RBAC result report is required.

## 4. What is created

- One `Microsoft.Authorization/roleAssignments` resource per valid entry in `rbac.resourceGroupAccess[]`.
- No user, group, service principal, managed identity, or resource group is created by this RBAC module.
- Repeated runs with the same target scope, principal, and role generate the same deterministic assignment name.

## 5. Deployment example

```powershell
az deployment sub what-if --location EastUS --template-file modules/RBAC/RBAC_resource_group.bicep --parameters resourceGroupName="<RESOURCE_GROUP>" principalId="<OBJECT_ID>" roleDefinitionGuid="acdd72a7-3385-48ef-bd42-f606fba81ae7" principalType="User"

az deployment sub create --name "rbac-resource-group" --location EastUS --template-file modules/RBAC/RBAC_resource_group.bicep --parameters resourceGroupName="<RESOURCE_GROUP>" principalId="<OBJECT_ID>" roleDefinitionGuid="acdd72a7-3385-48ef-bd42-f606fba81ae7" principalType="User"
```

The example GUID is the built-in **Reader** role.

## 6. Prerequisites and limitations

- The target resource group and Entra principal must already exist when this deployment runs.
- The workflow identity needs directory-read access to resolve the user and `Microsoft.Authorization/roleAssignments/write` at the target scope.
- The deploying identity must be allowed to create role assignments at the target scope (commonly User Access Administrator or Owner, subject to Azure conditions).
- The current workflow is user-only because it calls `az ad user show`; group and service-principal resolution is not implemented.
- The current input includes `roleDefinitionName`, but the workflow passes the GUID and does not cross-check the name against it. Keep the pair consistent and review it before deployment.
- Subscription-level and resource-level templates are not invoked by the current RBAC workflow.

## 7. Expected deployment result

For each successfully processed input object, Azure creates the requested role assignment and the Bicep deployment exposes both output values. A successful What-If is a preview, not proof that the subsequent deployment or access propagation has completed.
