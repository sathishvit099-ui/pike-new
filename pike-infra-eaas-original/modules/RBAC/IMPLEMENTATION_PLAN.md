# 🧭 RBAC Implementation Plan — Before and During Implementation

**Repository:** `PROMETHEUS-N/BIFROST_NEW`  
**Branch:** `feature/RBAC/mark1`  
**Area:** `modules/RBAC/` and `.github/workflows/deploy.yml`

This document is the implementation checklist for taking the current RBAC templates to a complete, ticket-driven, auditable RBAC workflow. It separates what already exists from what must be completed before production use.

---

## 1. Current implementation baseline

| Capability | Current state | Notes |
|---|---|---|
| Subscription-scope Bicep template | 🟡 Template exists | `RBAC_subscription.bicep`; not wired into workflow input |
| Resource-group-scope Bicep template | 🟢 Implemented | `RBAC_resource_group.bicep`; currently wired into `deploy.yml` |
| Resource-scope Bicep template | 🟡 Template exists | `RBAC_resource.bicep`; currently Storage Account-specific and not wired into workflow |
| RBAC input in `input.json` | 🟡 Partial | Currently has `rbac.resourceGroupAccess[]` only |
| User principal lookup | 🟢 Implemented for RG path | Uses `az ad user show` with `principalEmail` |
| Group / service-principal lookup | 🔴 Not implemented | Requires type-specific lookup logic |
| Role name-to-GUID validation | 🔴 Not implemented | `roleDefinitionName` is currently descriptive; workflow passes GUID without cross-checking |
| Scope-specific input/output documentation | 🟢 Documented | See the three scope README files |
| Central role ID catalogue | 🔴 To create | Recommended file: `ROLE_IDS.md` |
| RBAC output artifact / consolidated report | 🔴 Not implemented | Azure CLI output is shown, but no dedicated RBAC summary artifact is produced |

**Status meanings:** 🟢 implemented in the current branch; 🟡 partially implemented or template-only; 🔴 outstanding.

---

## 2. Decisions to make before implementation

Do not start extending the workflow until these decisions are confirmed in the Jira request / design review.

### 2.1 Principal types

Decide which principal types the workflow must support:

- [ ] User
- [ ] Group
- [ ] Service principal / application
- [ ] Managed identity (system-assigned or user-assigned)

For each type, define the ticket input and lookup method. The current workflow supports **users only** through `az ad user show`. The Bicep templates accept `User`, `Group`, and `ServicePrincipal`, but that does not mean the workflow can resolve all those types yet.

Prefer accepting an immutable Entra object ID when the ticketing system can provide one. If accepting an email, display name, or application/client ID, define an unambiguous lookup and duplicate/not-found failure policy.

### 2.2 Role selection and role IDs

- [ ] Decide whether tickets may specify a role by name, GUID, or both.
- [ ] Create and maintain `modules/RBAC/ROLE_IDS.md` (or another agreed central catalogue).
- [ ] Record role display name, role definition GUID, built-in/custom status, concise permission purpose, and supported scope notes.
- [ ] Validate that the supplied role name and GUID refer to the same role; do not silently trust mismatched values.
- [ ] Decide how custom roles are discovered and validated.
- [ ] Require approval for privileged roles such as Owner, User Access Administrator, and other roles that can grant access.

The current sample uses **Reader** with GUID `acdd72a7-3385-48ef-bd42-f606fba81ae7`. Treat it as an example, not a default for every request.

Useful discovery commands (run under an identity allowed to read role definitions):

```powershell
# List role names and IDs at subscription scope
az role definition list --query "[].{Name:roleName,Id:name,Type:roleType}" -o table

# Find one role by exact display name
az role definition list --name "Reader" --query "[].{Name:roleName,Id:name,AssignableScopes:assignableScopes}" -o json

# Inspect a known role definition GUID
az role definition list --name "acdd72a7-3385-48ef-bd42-f606fba81ae7" -o json
```

Review the result in the intended tenant/subscription. Do not copy a GUID from an unverified source.

### 2.3 Supported scopes and target identification

- [ ] Subscription scope: define whether the ticket supplies subscription ID or uses the authenticated target subscription.
- [ ] Resource-group scope: define resource group name and validate it against approved configuration / deployed resources.
- [ ] Resource scope: define resource type, resource group, resource name, and (where required) parent resource identifiers.
- [ ] Decide whether resource-level access must support Storage Accounts, VMs, Key Vaults, SQL resources, and other resource providers.
- [ ] For each supported resource type, implement a typed existing-resource declaration or dedicated Bicep template with a supported API version.

The current resource template is **Storage Account-specific**. Do not pass an arbitrary Azure resource ID to it and assume it will work for every resource type.

### 2.4 Assignment behavior

- [ ] Decide whether duplicate assignments should be treated as idempotent success or reported as already present.
- [ ] Decide whether multiple role assignments for one principal/scope are allowed.
- [ ] Define how assignment conditions, condition version, delegated managed identity, and description will be handled if required.
- [ ] Define whether revocation/removal is in scope. Current templates create role assignments; they do not implement a separate access-removal workflow.
- [ ] Decide whether role assignment expiry / PIM activation is required. Azure RBAC role assignments and Entra PIM eligibility/activation are different workflows and must not be conflated.

---

## 3. Proposed ticket input contract

Keep the ticket payload declarative: requesters describe the access they need; the workflow validates it and maps it to deployment parameters. Do not ask ticket creators to supply generated ARM JSON or Bicep deployment resource names.

Suggested shape (illustrative contract; not yet implemented end-to-end):

```json
{
  "rbac": {
    "subscriptionAccess": [
      {
        "subscriptionId": "<SUBSCRIPTION_ID>",
        "principal": {
          "type": "User",
          "identifier": "user@contoso.com"
        },
        "role": {
          "name": "Reader",
          "definitionGuid": "acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }
      }
    ],
    "resourceGroupAccess": [
      {
        "resourceGroupName": "<RESOURCE_GROUP>",
        "principal": {
          "type": "User",
          "identifier": "user@contoso.com"
        },
        "role": {
          "name": "Reader",
          "definitionGuid": "acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }
      }
    ],
    "resourceAccess": [
      {
        "resourceGroupName": "<RESOURCE_GROUP>",
        "resourceType": "Microsoft.Storage/storageAccounts",
        "resourceName": "<STORAGE_ACCOUNT>",
        "principal": {
          "type": "User",
          "identifier": "user@contoso.com"
        },
        "role": {
          "name": "Reader",
          "definitionGuid": "acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }
      }
    ]
  }
}
```

This is a proposed future schema, not the current schema. The current workflow expects `rbac.resourceGroupAccess[]` objects with flat fields: `resourceGroupName`, `principalEmail`, `principalType`, `roleDefinitionName`, and `roleDefinitionGuid`. Do not change the JSON shape until the workflow and validation code are updated together.

---

## 4. Scope-by-scope implementation contract

The three scope README files should remain the detailed reference for each module. Each one must document **all inputs, their source, validation, parameter mapping, outputs, output generation, and deployment behavior**.

| Scope | Current template inputs | Current outputs | Current implementation |
|---|---|---|---|
| Subscription | `principalId`, `roleDefinitionGuid`, `principalType`, optional `assignmentSeed` | `roleAssignmentId` | Template only |
| Resource group | `resourceGroupName`, `principalId`, `roleDefinitionGuid`, `principalType` | `roleAssignmentId`, `assignedResourceGroupId` | Integrated for user principals |
| Resource | `storageAccountName`, `principalId`, `roleDefinitionGuid`, `principalType` | `roleAssignmentId`, `assignedResourceId` | Storage Account template only |

### Output-generation model

- `roleDefinitionId` is built from the role definition GUID using `subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)`.
- The assignment name is generated deterministically using Bicep `guid()` from the target scope ID, principal ID, and role definition ID (plus optional `assignmentSeed` for subscription scope).
- `roleAssignmentId` is emitted from the deployed role assignment's `.id` property.
- `assignedResourceGroupId` is emitted from the existing resource group's `.id` property.
- `assignedResourceId` is emitted from the existing Storage Account's `.id` property.

A deployment output is not the same as a final access verification. If required, add a post-deployment step to query the role assignment and verify the principal, role, and scope.

---

## 5. Work that must be completed before production rollout

### A. Input and validation

- [ ] Agree the final Jira-to-`input.json` schema for all three scopes.
- [ ] Validate JSON schema, required fields, types, empty values, and unsupported principal/scope combinations.
- [ ] Reject unknown role names and invalid GUID formats.
- [ ] Cross-check role name against role GUID.
- [ ] Validate subscription ID and ensure the target subscription matches the authorized deployment context.
- [ ] Validate resource group and resource existence before deployment.
- [ ] Define behavior for empty arrays and malformed entries.

### B. Identity and authorization

- [ ] Confirm OIDC service principal / managed identity used by GitHub Actions.
- [ ] Grant only required directory-read permissions for principal lookup.
- [ ] Grant `Microsoft.Authorization/roleAssignments/write` at the narrowest required scope.
- [ ] Confirm role assignment permissions are not broader than operationally necessary.
- [ ] Test user, group, service principal, and managed identity resolution separately if those types are in scope.
- [ ] Ensure approval gates exist for privileged roles and production scopes.

### C. Bicep modules

- [ ] Build and lint all three templates with the repository's pinned/approved Bicep version.
- [ ] Confirm role definition resource IDs resolve correctly at subscription scope.
- [ ] Confirm deterministic assignment naming is stable and avoids unintended collisions.
- [ ] Add support for each required resource type with a typed existing-resource declaration or dedicated module.
- [ ] Decide whether assignment metadata / conditions / expiry are required.
- [ ] Document every parameter and every output in the scope-specific README.

### D. Workflow orchestration

- [ ] Add independent loops/jobs for subscription, resource-group, and resource assignments.
- [ ] Ensure dependencies reflect when target resources are created; RBAC should run after the target exists.
- [ ] Use What-If before each deployment and fail safely on validation errors.
- [ ] Decide whether one failed assignment should stop the entire RBAC stage or allow remaining entries to continue and report failures.
- [ ] Use unique deployment names and keep temporary parameter files in the runner temp directory.
- [ ] Never print secrets or sensitive identity data unnecessarily.

### E. Results and audit artifact

- [ ] Capture each requested assignment before deployment: scope, target, principal identifier/type, role name/GUID, and ticket ID.
- [ ] Capture resolved principal object ID (avoid exposing unnecessary personal data in public logs).
- [ ] Capture What-If result, deployment result, deployment name, assignment resource ID, and error message if failed.
- [ ] Verify the assignment exists after deployment using Azure CLI.
- [ ] Generate a machine-readable JSON result and a human-readable Markdown/CSV summary artifact.
- [ ] For each request, report one of: `DEPLOYED`, `SKIPPED`, `FAILED`, or `ALREADY_PRESENT`, with a reason.
- [ ] Upload the report even when an individual assignment fails; use an `always()` reporting job where appropriate.

### F. Testing

- [ ] Test one successful Reader assignment at each scope.
- [ ] Test invalid principal, missing principal, unsupported principal type, invalid role GUID, and role-name/GUID mismatch.
- [ ] Test missing resource group and missing target resource.
- [ ] Test insufficient role-assignment permissions.
- [ ] Test duplicate/repeated workflow execution for idempotency.
- [ ] Test multiple input entries with a mix of success and failure.
- [ ] Confirm output values and the generated artifact match the actual Azure role assignment.

---

## 6. Suggested implementation sequence

1. **Freeze the input contract** with the ticket/request owner.
2. **Create `ROLE_IDS.md`** and agree role approval / validation policy.
3. **Complete scope documentation** (inputs, sources, validation, generated parameters, outputs, generation logic, limitations).
4. **Implement robust principal resolution** for the approved principal types.
5. **Implement role name/GUID validation** and scope validation.
6. **Wire subscription-scope deployment** into the workflow.
7. **Extend resource-scope templates and workflow** for the resource types actually required.
8. **Add per-entry error handling and final result artifact**.
9. **Run What-If and test cases** in a non-production subscription.
10. **Obtain security / platform approval** before production use.

---

## 7. Definition of done

The RBAC implementation is ready for production review only when:

- All approved scopes and principal types are supported end-to-end.
- Every ticket field is validated and mapped to a documented Bicep parameter.
- Every Bicep output is documented and its generation logic is clear.
- Role name and GUID are validated against an authoritative role definition.
- The workflow produces a per-request result with deployed/skipped/failed status and reason.
- Post-deployment verification confirms the actual assignment scope, principal, and role.
- Tests cover success, validation failure, authorization failure, duplicate execution, and mixed outcomes.
- The security owner approves the permissions and privileged-role controls.

---

## 8. Reference files

- `README_subscription.md` — subscription-scope input/output contract.
- `README_resource_group.md` — resource-group scope and current workflow mapping.
- `README_resource.md` — resource-scope contract and Storage Account limitation.
- `RBAC_subscription.bicep`, `RBAC_resource_group.bicep`, `RBAC_resource.bicep` — scope templates.
- `input.json` — current ticket-driven deployment input.
- `.github/workflows/deploy.yml` — deployment orchestration and current RG-only RBAC job.
