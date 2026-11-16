# Resilient Modular Deployment Guide

## What changed

The workflow in `.github/workflows/deploy.yml` now aims to process configured resource instances independently:

- Resource-type arrays in `input.json` are optional. A missing, null, or empty array is skipped rather than rejected by the initial validation step.
- Before a resource type is deployed, the workflow checks whether its Bicep module exists. If the module is missing, that resource type is skipped with a warning.
- Explicit Azure What-If and deployment failures inside a resource loop are reported as warnings and the loop continues to the next configured item.
- Deployment jobs use `always()` while still requiring successful input prechecks and Azure OIDC login. This prevents a failed earlier deployment job from automatically skipping every later job.
- Each deployment instance gets a unique deployment name suffix. This avoids collisions when multiple instances of the same resource type are deployed in one workflow run.

## Can multiple resources of the same type be deployed?

**Yes.** Put each instance in the relevant JSON array under `landingZones`. The workflow iterates through the array and deploys each entry separately.

For example, two resource groups can be configured like this:

```json
{
  "environment": "dev",
  "landingZones": {
    "resourceGroups": [
      {
        "rgName": "rg-app-dev-eastus-001",
        "location": "eastus",
        "tags": {
          "Environment": "dev",
          "Workload": "app-one",
          "ManagedBy": "Bicep"
        }
      },
      {
        "rgName": "rg-data-dev-eastus-001",
        "location": "eastus",
        "tags": {
          "Environment": "dev",
          "Workload": "data-platform",
          "ManagedBy": "Bicep"
        }
      }
    ]
  }
}
```

The same pattern applies to VNets, subnets, NSGs, route tables, VMs, Key Vaults, storage accounts, SQL databases, OpenAI services, load balancers, Application Gateway subnets, and Application Gateways.

Each array item must contain all properties required by its corresponding Bicep module. Resource names must be unique where Azure requires uniqueness.

## Supported resource arrays and module paths

| JSON array under `landingZones` | Bicep module |
|---|---|
| `resourceGroups` | `modules/RG/resourcegroup.bicep` |
| `nsgs` | `modules/networking/nsg.bicep` |
| `routeTables` | `modules/networking/routetable.bicep` |
| `vnets` | `modules/networking/vnet.bicep` |
| `subnets` | `modules/networking/subnet.bicep` |
| `loadBalancers` | `modules/loadbalancer/lb.bicep` |
| `applicationGatewaySubnets` | `modules/networking/applicationGatewaySubnet.bicep` |
| `applicationGateways` | `modules/networking/applicationGateway.bicep` |
| `keyVaults` | `modules/security/keyvault.bicep` |
| `storageAccounts` | `modules/storage/storageAccount.bicep` |
| `sqlDatabases` | `modules/database/sql.bicep` |
| `openAiServices` | `modules/ai/openai.bicep` |
| `vms` | `modules/compute/vm.bicep` |

RBAC uses optional arrays under the root-level `rbac` object: `subscriptionAccess`, `resourceGroupAccess`, and `resourceAccess`. Its processing function records individual assignment failures and proceeds to other entries.

## Missing or failed modules

- **Array omitted or empty:** the corresponding resource-type job logs that it has nothing to deploy and skips the type.
- **Bicep module file missing:** the corresponding job logs a warning and skips that type. Later jobs can still run.
- **Bicep compile failure:** the precheck reports the module build failure as a warning and continues checking other modules. The deployment stage for that module may still fail if Azure cannot deploy it.
- **What-If or Azure deployment command returns a failure:** the affected item is warned about and the loop proceeds to the next item.
- **Precheck or Azure authentication failure:** deployment does not proceed. These are deliberate prerequisites, not resource-level failures.

## Dependency caveat

Continuing the workflow does **not** remove real Azure dependencies. For example, a subnet requires its VNet, a VM requires its network dependencies, and an Application Gateway requires its subnet and related networking resources. If a prerequisite failed, a dependent deployment may also fail. The workflow will attempt later resource types, but Azure cannot successfully create a resource whose required dependencies do not exist.

The current job order remains dependency-oriented. Jobs can run after earlier deployment jobs report failure, but resource dependencies still determine whether the Azure deployment itself can succeed.

## Running and checking the workflow

1. Update `input.json` on the `ORIGINAL` branch with one or more objects in each resource array.
2. Confirm the relevant Bicep module exists at the path in the table above.
3. Open **Actions** in GitHub.
4. Select **PIKE Modular Azure Infrastructure Deployment**.
5. Choose **Run workflow** and select the `ORIGINAL` branch.
6. Review each job's logs for `Skipping`, `WARNING`, What-If failures, and deployment failures.

A warning that an item failed does not mean it was deployed. Check the Azure deployment result and the target resource in Azure before treating it as successful.

## Important operational note

This workflow is best-effort at the resource level. A job can finish while reporting warnings for individual resources. Review the logs; do not use the overall workflow status alone as proof that every configured resource was created.
