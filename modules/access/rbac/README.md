# 🔐 Azure RBAC modules

This directory contains the Bicep templates used to create Azure role assignments at subscription, resource-group, and supported individual-resource scopes. The detailed scope-specific documentation and implementation notes are kept in `docs/`.

## Directory structure

```text
modules/
└── access/
    └── rbac/
        ├── README.md
        ├── RBAC_subscription.bicep
        ├── RBAC_resource_group.bicep
        ├── RBAC_resource.bicep
        └── docs/
            ├── IMPLEMENTATION_PLAN.md
            ├── README_subscription.md
            ├── README_resource_group.md
            └── README_resource.md
```

### Bicep templates

| File | Intended scope | Purpose |
|---|---|---|
| `RBAC_subscription.bicep` | Subscription | Assigns a role to an existing Entra principal at the subscription scope |
| `RBAC_resource_group.bicep` | Resource group | Assigns a role to an existing Entra principal at resource-group scope |
| `RBAC_resource.bicep` | Individual resource | Assigns a role to an existing principal on an existing Storage Account |

The resource-level template is currently Storage Account-specific. Other resource types require a matching typed `existing` declaration or a dedicated template.

## How deployment is orchestrated

The repository's `.github/workflows/deploy.yml` contains a `deploy-rbac` job. It runs after the VM deployment job and authenticates to Azure using the repository's GitHub Actions OIDC configuration.

The job:

1. Reads the RBAC entries from `input.json`.
2. Resolves the requested principal. The current lookup implementation supports users through `az ad user show`; group and service-principal lookup are not implemented.
3. Builds a temporary ARM deployment-parameters JSON file in the runner's temporary directory.
4. Runs Azure What-If before applying each requested assignment.
5. Deploys the selected Bicep template and collects the returned role-assignment ID.
6. Writes a JSON results file and uploads it as the RBAC deployment artifact.

### Current workflow integration

| Input collection | Template | Workflow status |
|---|---|---|
| `rbac.subscriptionAccess[]` | `RBAC_subscription.bicep` | Workflow has a processing path; ensure the input supplies the deployment location expected by the workflow |
| `rbac.resourceGroupAccess[]` | `RBAC_resource_group.bicep` | Workflow integration present |
| `rbac.resourceAccess[]` | `RBAC_resource.bicep` | Workflow integration present for Storage Accounts only |

**Important implementation caveat:** The workflow and Bicep parameter contract must remain aligned. In particular, verify that the resource-group template accepts the parameters the workflow generates and that the subscription deployment location is supplied by the current `input.json` structure. The detailed current contracts and outstanding work are documented in `docs/IMPLEMENTATION_PLAN.md` and the scope-specific documents.

## Documentation

- [Subscription-scope RBAC](docs/README_subscription.md)
- [Resource-group-scope RBAC](docs/README_resource_group.md)
- [Resource-scope RBAC](docs/README_resource.md)
- [Implementation plan and production-readiness checklist](docs/IMPLEMENTATION_PLAN.md)

## Prerequisites

- The target subscription, resource group, resource, and Entra principal must already exist.
- The GitHub Actions identity must be authenticated to the intended Azure tenant and subscription.
- The deployment identity must have `Microsoft.Authorization/roleAssignments/write` permission at the target scope.
- Principal lookup requires appropriate Microsoft Entra directory-read permissions.
- Review What-If output and role privilege before applying assignments.

## Important distinction: RBAC and PIM

These templates create Azure RBAC role assignments. They do not configure Microsoft Entra Privileged Identity Management (PIM) eligibility, activation, approval, or time-bound activation policies. PIM is a separate implementation.
