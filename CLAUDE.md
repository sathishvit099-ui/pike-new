# CLAUDE.md — Pike Azure Infrastructure Naming and Deployment Standards

> **Purpose:** Instructions for Claude Code working in this repository. Follow these rules before changing code, configuration, or workflows.
>
> **Non-negotiable:** Do not create new Azure resource modules for the 37 resource types listed below. Reuse the modules that already exist in this repository. Do not change existing SKU, sizing, image, networking, or other deployment values unless explicitly asked.

## 1. Start by inspecting the repository

Before making changes:

1. Inspect the repository tree, the current workflow YAML files, all existing resource modules, and the current `input.json` (including its actual path).
2. Identify the default branch and the existing deployment entry point.
3. Build an inventory of the modules that actually exist. Do not assume that every one of the 37 resource types has a module.
4. Read the current `input.json` and preserve its existing values. Do not invent or silently replace SKU, VM size, image reference, PostgreSQL configuration, region, networking, tags, or other deployment properties.
5. Identify how the current workflow maps input properties to module inputs, and how it authenticates to Azure.
6. Record any ambiguity or missing input in a short findings section before implementing. Ask for clarification only if a safe implementation is impossible; otherwise use the documented defaults in this file and mark them as assumptions.

**Input-file rule:** The user has not supplied the contents of the current repository `input.json` in this request. Therefore, discover and read the real file from the checked-out repository. Never fabricate a replacement input file from this instruction document.

## 2. Naming tokens

Use lowercase letters and hyphens for Azure resource names unless the Azure resource type disallows hyphens or has a different character rule.

| Token | Allowed values / meaning |
|---|---|
| `<env>` | `dev`, `qa`, `uat`, `prod` |
| `<workload>` | `platformsvc`, `sharedinfra` |
| `<system>` | `sap`, `okta`, `fleet` |
| `<domain>` | `hr`, `finance`, `ops` |
| `<purpose>` | A short functional token from the approved vocabulary below |

### Purpose vocabulary

Choose the shortest accurate purpose token. Do not put every token into every resource name.

| Purpose token | Use |
|---|---|
| `api` | API endpoint or API hosting |
| `web` | Web front end |
| `app` | General application |
| `worker` | Background worker |
| `batch` | Batch processing |
| `sync` | Synchronization job |
| `integration` | System integration |
| `data` | General data service |
| `db` | Database service where a more specific token is not needed |
| `orders` | Orders business capability |
| `users` | User / identity business capability |
| `files` | File storage or file processing |
| `lake` | Data lake |
| `cache` | Cache |
| `events` | Event processing |
| `queue` | Queue messaging |
| `topic` | Topic messaging |
| `logs` | Logs |
| `monitor` | Monitoring |
| `audit` | Audit records |
| `backup` | Backup |
| `network` | Network infrastructure |
| `private` | Private connectivity |
| `public` | Public-facing endpoint |
| `bastion` | Administrative jump access |
| `gateway` | Network or application gateway |
| `firewall` | Firewall function |
| `identity` | Identity-related workload |
| `security` | Security function |
| `analytics` | Analytics workload |
| `reporting` | Reporting workload |
| `exceptions` | Exception handling |

For a resource tied to a known system and domain, prefer a meaningful combination such as `sap-hr`, `okta-users`, or `fleet-ops`. Do not include both `<system>` and `<domain>` when one is sufficient or when the Azure name limit makes the result too long.

### General name construction

Use this conceptual order where the resource permits it:

`<resource-prefix>-pike-<workload-or-system-or-domain>-<purpose>-<env>`

This is a guideline, not a requirement to force all tokens into every name. Keep the resource-specific patterns in Section 3 as the source of truth. The reference standard uses resource prefixes and the `pike` project identifier, for example `sbns-pike-prod`, `psql-pike-mdm-prod`, `afd-pike-prod`, `kv-pike-sapord-prod`, and `vnet-pike-dev`.

## 3. Resource naming catalogue — all 37 requested types

Examples below use the `dev` environment. Replace `dev` with `qa`, `uat`, or `prod` as appropriate. Patterns intentionally omit tokens that do not add useful identity or cannot fit the Azure limit. Claude Code must validate every final name against the actual Azure resource provider rules before deployment.

| # | Azure resource | Pattern | Dev example | Notes |
|---:|---|---|---|---|
| 1 | Azure OpenAI | `oai-pike-<purpose>-<env>-<unique>` | `oai-pike-ai-dev-a1b2` | Azure OpenAI account names have provider-specific rules; verify the current limit and allowed characters. Use a short deterministic unique suffix if uniqueness is required. |
| 2 | Front Door | `afd-pike-<env>` | `afd-pike-dev` | Front Door profile name; endpoint host name is a separate globally unique DNS label and needs its own unique suffix. |
| 3 | Application Gateway (Layer 7) | `agw-pike-<purpose>-<env>` | `agw-pike-public-dev` | Use `gateway` purpose if not public-facing. |
| 4 | Azure Bastion | `bas-pike-<env>` | `bas-pike-dev` | Bastion is deployed in a VNet/subnet with the required reserved subnet name `AzureBastionSubnet`; do not rename that subnet. |
| 5 | Azure DNS zone | `dns-pike-<domain>` | `dns-pike-hr` | DNS zone names follow DNS naming rules. The actual DNS zone/FQDN must be supplied and must not be invented. |
| 6 | Private Link / Private Endpoint | `pe-pike-<purpose>-<env>` | `pe-pike-sql-dev` | Private Link is a platform capability; the Private Endpoint is the named resource. Use one endpoint name per target/service/purpose. |
| 7 | VM — Windows | `vm-pike-<system>-<purpose>-win-<env>` | `vm-pike-sap-app-win-dev` | Azure VM resource name and Windows computer/host name have different limits. Validate both separately. |
| 8 | VM — Windows with SQL image | `vm-pike-<system>-<purpose>-sql-<env>` | `vm-pike-sap-db-sql-dev` | Reuse the existing VM module; select the SQL image through `VM_WINDOWS_SQL_IMAGE`. |
| 9 | Azure SQL logical server | `sql-pike-<system>-<purpose>-<env>-<unique>` | `sql-pike-sap-orders-dev-a1b2` | Logical server DNS name is globally unique. Use only lowercase letters, numbers, and hyphens where supported; validate provider limits. |
| 10 | PostgreSQL Flexible Server | `psql-pike-<purpose>-<env>-<unique>` | `psql-pike-mdm-dev-a1b2` | Server name is globally unique. Database names are separate and should use `<purpose>` / `<module>` as in the reference (`platform`, `exceptions`). |
| 11 | Cosmos DB account | `cosmos-pike-<purpose>-<env>-<unique>` | `cosmos-pike-users-dev-a1b2` | Account name is globally unique and has strict lowercase alphanumeric rules; omit hyphens if the provider requires it. |
| 12 | Storage account | `stpike<purpose><env><unique>` | `stpikefilesdeva1b2` | 3–24 characters, lowercase letters and numbers only; globally unique. No hyphens. |
| 13 | Key Vault | `kv-pike-<short-purpose>-<env>-<unique>` | `kv-pike-sapord-dev-a1b2` | Vault name is globally unique; validate length and provider naming rules. Keep suffix short. |
| 14 | VM — Linux | `vm-pike-<system>-<purpose>-lnx-<env>` | `vm-pike-fleet-worker-lnx-dev` | Validate Azure resource name separately from Linux hostname. |
| 15 | AKS cluster | `aks-pike-<workload>-<env>` | `aks-pike-platformsvc-dev` | Also validate node resource group and DNS prefix; these are distinct names. |
| 16 | Azure Container App | `ca-<workload>-<purpose>-<env>` | `ca-platformsvc-api-dev` | Container App names have provider-specific length and character constraints. |
| 17 | Azure Container Registry | `crpike<purpose><env><unique>` | `crpikeplatformdev1a2b` | 5–50 alphanumeric characters, globally unique; no hyphens. |
| 18 | Azure App Service (Web App) | `app-pike-<purpose>-<env>-<unique>` | `app-pike-kbase-dev-a1b2` | App Service default hostname is globally unique. App Service Plan is a separate resource and should have its own name. |
| 19 | Logic App | `logic-pike-<system>-<purpose>-<env>` | `logic-pike-sap-orders-dev` | Use `logic` consistently for Logic Apps; validate workflow type-specific requirements. |
| 20 | Azure Function App | `func-pike-<system>-<purpose>-<env>-<unique>` | `func-pike-sap-sync-dev-a1b2` | Function App hostname is globally unique. Storage account dependency must use its own compliant name. |
| 21 | Azure Cache for Redis | `redis-pike-<purpose>-<env>` | `redis-pike-session-dev` | Validate the selected Redis offering and current provider naming/availability rules; do not silently change SKU. |
| 22 | Event Grid topic / domain | `eg-pike-<domain>-<env>` | `eg-pike-hr-dev` | Use a separate event subscription naming pattern such as `egs-<target>` where applicable. |
| 23 | Service Bus namespace | `sbns-pike-<env>-<unique>` | `sbns-pike-dev-a1b2` | Namespace name is globally unique. Queue: `q-<system>-<entity>` (e.g. `q-sap-orders`); topic: `sbt-<domain>-<event>`; subscription: `sbs-<target>`. |
| 24 | Azure VPN Gateway | `vpngw-pike-<purpose>-<env>` | `vpngw-pike-hub-dev` | Gateway is associated with a VNet; required gateway subnet name is `GatewaySubnet`. |
| 25 | Standard Load Balancer | `lb-pike-<purpose>-<env>` | `lb-pike-app-dev` | Use `lb` for Layer 4 load balancer; keep distinct from Application Gateway (`agw`). |
| 26 | Data Lake Storage Gen2 | `stpikelake<env><unique>` | `stpikelakedev1a2b` | Usually a Storage Account with hierarchical namespace enabled, not a separate resource type. Apply storage account naming rules. |
| 27 | Power BI | `pbi-pike-<purpose>-<env>` | `pbi-pike-reporting-dev` | Power BI workspace/artifact naming is not Azure ARM resource naming. Confirm whether the target is workspace, capacity, or another artifact. |
| 28 | Microsoft Fabric | `fabric-pike-<purpose>-<env>` | `fabric-pike-analytics-dev` | Confirm whether this means Fabric capacity, workspace, or item; names and deployment APIs differ. |
| 29 | ACS (assumed Azure Communication Services) | `acs-pike-<purpose>-<env>-<unique>` | `acs-pike-notify-dev-a1b2` | Confirm that ACS means Azure Communication Services. Its resource name has provider-specific constraints. |
| 30 | Public allowed / not allowed | Not a resource name; use `PUBLIC_ACCESS` | `PUBLIC_ACCESS=false` | Store as an explicit Boolean environment variable or resource input. Default to `false` unless approved otherwise. Enforce with the appropriate public network access setting and/or network controls. |
| 31 | Managed Identity / GitHub OIDC | `id-pike-<workload>-<purpose>-<env>` | `id-pike-platformsvc-deploy-dev` | Managed identity is an Azure identity resource. GitHub OIDC is a federated credential/trust configuration, not a managed identity itself. |
| 32 | PIM | `pim-pike-<purpose>-<env>` (configuration label only) | `pim-pike-privileged-dev` | PIM is a Microsoft Entra privileged-access capability, not an Azure resource/module equivalent to Managed Identity. Use this label for PIM-related configuration/documentation only. |
| 33 | RBAC | `rbac-pike-<scope-purpose>-<env>` (assignment label only) | `rbac-pike-resource-reader-dev` | RBAC role assignments are scope/role/principal relationships; this is a logical label, not necessarily an Azure resource name. |
| 34 | Virtual Network | `vnet-pike-<workload>-<env>` | `vnet-pike-platformsvc-dev` | Keep the name concise and consistent with the reference `vnet-pike-<env>` where a shared VNet is used. |
| 35 | Subnet | `snet-<purpose>` | `snet-container-apps` | Subnets are named within a VNet. Use purpose-based names; retain Azure-required names such as `AzureBastionSubnet` and `GatewaySubnet` exactly. |
| 36 | Network Security Group | `nsg-pike-<purpose>-<env>` | `nsg-pike-app-dev` | If NSG is subnet-specific, use a concise purpose such as `aks`, `app`, or `data`. |
| 37 | Route Table | `rt-pike-<purpose>-<env>` | `rt-pike-private-dev` | Associate with the relevant subnet; do not put subnet CIDRs or other mutable configuration into the name. |

### Name generation and uniqueness rules

1. Use `dev`, `qa`, `uat`, and `prod` exactly as the environment tokens.
2. Use `platformsvc` and `sharedinfra` exactly as the workload values in configuration. In names, shorten only when a provider limit requires it, and document the approved abbreviation.
3. Use the system values `sap`, `okta`, and `fleet`; use domain values `hr`, `finance`, and `ops`.
4. Do not add instance numbering such as `01`, `02`, or `001`.
5. For globally unique names, append a short stable suffix (for example, a deterministic 4–6 character lowercase alphanumeric suffix derived from a stable input such as the subscription/resource identity). Do not generate a new random suffix on every run, because that would cause replacement or name drift.
6. Check for collisions and provider naming constraints before deployment. If a deterministic suffix cannot guarantee uniqueness, fail validation with a clear message rather than silently deploying a different name.
7. Do not include secrets, subscription IDs, client IDs, tenant IDs, or other sensitive values in resource names, tags, logs, or CSV output.
8. Azure naming rules differ by resource provider and can change. Treat the table as the Pike naming standard, then validate against current provider constraints and the actual API/template schema. If a name cannot satisfy both, preserve the intent with the shortest compliant name and document the exception.
9. Do not assume every resource name supports hyphens. Storage Accounts and ACR are examples where hyphens are not allowed.
10. Names in this catalogue are proposed standards. Existing deployed resource names must not be renamed automatically; renaming an Azure resource can require replacement.

## 4. Module and input-file requirements

1. Do **not** create any new resource modules for the 37 items in Section 3.
2. Reuse only modules already present in the repository. Do not create placeholder modules for missing resource types.
3. Generate/update a Markdown inventory (for example `docs/resource-naming-standard.md`) containing all 37 rows from Section 3, plus any existing module path and whether the resource is currently implemented.
4. Generate/update the deployment `input.json` only after inspecting the current file and module contracts. Preserve all existing values and schema unless a narrowly scoped change is required.
5. Include only module/resource definitions that are supported by existing modules. If a listed resource has no module, record `Not currently implemented — no module created` in the inventory.
6. Do not remove or reorder existing resources in a way that changes deployment dependencies. Preserve existing resource dependencies and outputs.
7. If one input contains multiple resources of the same type, support all entries if the existing module and workflow already support multiple instances. Do not silently overwrite one resource with another. If the current schema supports only one instance, document the limitation and propose the smallest backward-compatible extension before changing it.
8. Validate JSON syntax and schema before running deployment. Never deploy based on guessed inputs.

## 5. GitHub Environments, secrets, and variables

Create/use four GitHub Environments with these exact names:

- `dev`
- `qa`
- `uat`
- `prod`

Each GitHub Environment represents exactly one Azure subscription. The workflow must select the GitHub Environment from the deployment input and use credentials from that same environment. Do not mix secrets or variables across environments.

### 5.1 Secrets in each GitHub Environment

Configure the following secrets separately in each of `dev`, `qa`, `uat`, and `prod`:

| Secret name | Purpose |
|---|---|
| `AZURE_SUBSCRIPTION_ID` | Subscription ID for that environment |
| `AZURE_CLIENT_ID` | Entra application / workload identity client ID |
| `AZURE_TENANT_ID` | Entra tenant ID |

Use GitHub OIDC federation with `azure/login` where the repository's current authentication model supports it. Do not add a client secret if OIDC is configured. The workflow should grant the minimum required permissions, normally `id-token: write` and `contents: read`. Never print secret values.

### 5.2 Non-secret environment variables

All non-secret configuration belongs in the corresponding GitHub Environment's **Variables**, not in repository-wide secrets. Keep values separated by environment. The same variable key may have different values in `dev`, `qa`, `uat`, and `prod`.

Use the actual resource types and properties discovered in `input.json` to generate the final inventory. The following naming scheme is the required starting convention; include a variable in the generated inventory only when the current input/module needs it.

| Variable key pattern | Example key | Typical value / use |
|---|---|---|
| VM Windows image | `VM_WINDOWS_IMAGE` | Exact current Windows image reference from input |
| VM Linux image | `VM_LINUX_IMAGE` | Exact current Linux image reference from input |
| VM Windows SQL image | `VM_WINDOWS_SQL_IMAGE` | Exact current Windows + SQL image reference from input |
| VM size by type | `VM_WINDOWS_SIZE`, `VM_LINUX_SIZE`, `VM_WINDOWS_SQL_SIZE` | Existing VM SKU/size, unchanged |
| VM disk settings | `VM_OS_DISK_SIZE_GB`, `VM_DATA_DISK_SIZE_GB`, `VM_DISK_TYPE` | Existing disk values, only if used |
| VM admin username | `VM_ADMIN_USERNAME` | Non-secret username only; password/private key remains a secret |
| PostgreSQL | `POSTGRESQL_VERSION`, `POSTGRESQL_SKU`, `POSTGRESQL_STORAGE_SIZE_GB`, `POSTGRESQL_TIER`, `POSTGRESQL_BACKUP_RETENTION_DAYS`, `POSTGRESQL_HA_MODE` | Exact values already present in input; include only applicable keys |
| Azure SQL | `AZURE_SQL_SKU`, `AZURE_SQL_MAX_SIZE_GB`, `AZURE_SQL_TIER` | Existing values |
| Cosmos DB | `COSMOSDB_API`, `COSMOSDB_SKU`, `COSMOSDB_CONSISTENCY_LEVEL` | Existing values |
| AKS | `AKS_VERSION`, `AKS_VM_SIZE`, `AKS_NODE_COUNT`, `AKS_MAX_NODE_COUNT`, `AKS_NETWORK_PLUGIN` | Existing values |
| Container Apps | `CONTAINER_APPS_ENV_WORKLOAD_PROFILE`, `CONTAINER_APP_CPU`, `CONTAINER_APP_MEMORY` | Existing values |
| ACR | `ACR_SKU`, `ACR_ADMIN_ENABLED` | Existing values |
| App Service | `APP_SERVICE_PLAN_SKU`, `APP_SERVICE_RUNTIME` | Existing values |
| Function App | `FUNCTION_APP_RUNTIME`, `FUNCTION_APP_PLAN_SKU` | Existing values |
| App Gateway | `APP_GATEWAY_SKU`, `APP_GATEWAY_CAPACITY`, `APP_GATEWAY_TIER` | Existing values |
| Load Balancer | `LOAD_BALANCER_SKU`, `LOAD_BALANCER_TIER` | Existing values |
| Front Door | `FRONT_DOOR_SKU`, `FRONT_DOOR_TIER` | Existing values |
| Redis | `REDIS_SKU`, `REDIS_CAPACITY`, `REDIS_VERSION` | Existing values |
| Storage / Data Lake | `STORAGE_ACCOUNT_SKU`, `STORAGE_REPLICATION`, `STORAGE_HNS_ENABLED`, `DATA_LAKE_HNS_ENABLED` | Existing values |
| Key Vault | `KEY_VAULT_SKU`, `KEY_VAULT_RBAC_AUTHORIZATION` | Existing values |
| OpenAI | `AZURE_OPENAI_SKU`, `AZURE_OPENAI_MODEL`, `AZURE_OPENAI_MODEL_VERSION`, `AZURE_OPENAI_CAPACITY` | Existing values |
| Networking | `VNET_ADDRESS_PREFIX`, `SUBNET_*_PREFIX`, `NSG_*`, `ROUTE_TABLE_*` | Existing CIDRs/rules/routes |
| Region | `AZURE_LOCATION` | Existing deployment location |
| Public access | `PUBLIC_ACCESS` | `true` or `false`; default `false` unless approved |
| RBAC Reader | `RBAC_READER_ROLE_DEFINITION_ID` | Built-in Reader role definition GUID, if used |
| PIM Reader | `PIM_READER_ROLE_DEFINITION_ID` | Reader role definition GUID for eligible PIM assignment, if used |
| PIM policy | `PIM_APPROVAL_REQUIRED`, `PIM_MAX_DURATION`, `PIM_JUSTIFICATION_REQUIRED` | Policy/configuration values only if the current PIM implementation supports them |

**Important:** The table is not permission to add made-up values or change the existing deployment settings. Extract the actual values from the current `input.json` and module parameter definitions. If an input value is absent, show it as `Not present in input.json — owner to provide`; do not invent a default. If a property is secret (password, token, private key), it must not be a GitHub Environment variable.

### 5.3 Generate the environment-variable inventory

Generate a Markdown file, for example `docs/github-environment-variables.md`, based on the real `input.json` and existing module schemas.

It must contain:

- Environment name (`dev`, `qa`, `uat`, `prod`).
- Required GitHub Environment secrets (names only; never values).
- Every non-secret variable actually required by the current input/module combination.
- Current value copied exactly from `input.json` (or a clear note if absent).
- Which resource/module consumes the variable.
- Whether it is required or optional.
- Whether it is common to all environments or environment-specific.
- A clear separation between secrets and variables.

The requested example variable names must be used for the three VM image categories:
- Windows VM image: `VM_WINDOWS_IMAGE`
- Linux VM image: `VM_LINUX_IMAGE`
- Windows VM with SQL image: `VM_WINDOWS_SQL_IMAGE`

If the input has several VMs of the same category but different images/sizes, do not collapse different values into one ambiguous variable. Propose a stable per-instance or per-role variable key and document the mapping, while retaining the requested base naming convention.

Do not copy secret values into Markdown. The environment-variable document may show non-secret values from `input.json`; it must not show credentials.

## 6. Managed Identity, GitHub OIDC, PIM, and RBAC

The instruction that “Managed Identity means PIM” is technically incorrect. They are different Azure/Entra concepts. Follow this distinction while using the user's preferred `PIM` wording for privileged access documentation:

- **Managed Identity:** An identity assigned to an Azure resource (system-assigned or user-assigned) so the workload can authenticate without storing credentials.
- **GitHub OIDC:** Federated authentication from GitHub Actions to Microsoft Entra ID. It uses a federated identity credential on an Entra application or user-assigned managed identity, depending on the chosen architecture. It is not itself a managed identity.
- **RBAC:** Grants a principal a role at a scope, such as subscription, resource group, or resource.
- **PIM:** Privileged Identity Management controls eligible/just-in-time privileged role activation, approval, duration, and related governance. It is not a managed identity and does not replace RBAC.

Use `PIM` as the heading/label for privileged access controls, as requested. Do not rename an existing Managed Identity module or resource to PIM, and do not remove the actual managed identity configuration. If the repository contains a module named `managed-identity`, preserve it and explain its relationship to GitHub OIDC and RBAC in the documentation.

### Reader role configuration

- The built-in Azure Reader role definition ID is `acdd72a7-3385-48ef-bd42-f606fba81ae7`.
- It is reasonable to expose a role definition ID as a non-secret environment variable when the workflow intentionally supports configurable role selection. Use `RBAC_READER_ROLE_DEFINITION_ID` for standard RBAC Reader assignments.
- For PIM, a Reader role may be made eligible through the applicable Entra/Azure PIM workflow and supported API. Use `PIM_READER_ROLE_DEFINITION_ID` only if the current implementation actually consumes it.
- Do not assume that a PIM eligible assignment is interchangeable with a normal RBAC role assignment. Validate the target scope, principal type, role definition, assignment schedule, approval settings, and API/module support.
- Role definition IDs are not secrets. Principal/object IDs are identifiers, not credentials, but should still be handled carefully and not printed unnecessarily.
- Do not implement PIM or RBAC by creating a new module if the user has explicitly said not to create new modules. Reuse existing supported modules or document the missing capability.

## 7. Deploy only resources present in input.json

The workflow must run only the resource/module deployments represented in the current `input.json`. Do not display or execute skipped module stages as if they were active deployments.

Required behavior:

1. A preparation/validation stage reads `input.json`.
2. It determines which supported module entries are present and valid.
3. It emits a deployment plan containing only those entries, in dependency-safe order.
4. The deployment stage processes only that plan.
5. Missing resource types are skipped and are not shown as active deployment stages.
6. Invalid entries fail validation with a clear message; do not silently deploy partial or guessed values.
7. Preserve required dependencies. For example, a resource that depends on a VNet must not run before the VNet exists.
8. Keep deployments sequential: do not run resource deployments in parallel.

### Is a dynamic sequential matrix suitable?

A GitHub Actions dynamic matrix can be generated from `input.json` and can contain only the selected modules. A matrix normally runs jobs in parallel. Setting `strategy.max-parallel: 1` limits concurrency to one matrix job at a time, and `fail-fast: false` prevents one matrix failure from cancelling queued matrix jobs. However, **GitHub does not provide a strong execution-order guarantee for matrix jobs**. Therefore, `max-parallel: 1` is not sufficient when strict dependency order is required.

**Preferred implementation for this repository:** use one deployment job that reads the validated deployment plan and loops through its entries sequentially, invoking the existing module deployment mechanism for each entry. This guarantees order and avoids parallel deployment. Use a dynamic matrix only if the modules are independent and strict order is not required. Do not use a matrix merely to make the workflow look dynamic.

If the current repository architecture requires a matrix, document the ordering limitation and do not claim strict sequence unless the workflow explicitly enforces dependencies/order.

### Failure handling

- Continue to the next independent module when a module deployment fails only if that is the established requested behavior and the workflow records the failure accurately.
- Do not continue past a failed prerequisite when dependent resources cannot safely deploy.
- At the end, return a failing workflow status if any required deployment failed, even if later independent modules were attempted.
- Capture each module's result (`Succeeded`, `Failed`, `Skipped`) and error summary.

## 8. End-of-run CSV inventory

At the end of every workflow run, generate a CSV containing the resources that were actually attempted/deployed and their resulting names/details.

Suggested path: `artifacts/deployment-inventory-<run-id>.csv` (or the repository's established artifact path).

Minimum columns:

- `run_id`
- `timestamp_utc`
- `environment`
- `subscription_id` (do not include if policy treats it as sensitive; never include client or tenant secrets)
- `resource_type`
- `module_name`
- `resource_name`
- `resource_group`
- `location`
- `sku`
- `size_or_tier`
- `image_or_runtime`
- `public_access`
- `deployment_status`
- `resource_id` (if returned)
- `error_summary`

Rules:

1. Include actual deployed outputs wherever possible; do not report a resource as deployed merely because it exists in `input.json`.
2. Include failed and skipped entries with accurate status where useful for auditability.
3. Never include passwords, tokens, client secrets, private keys, or other credentials.
4. Escape CSV values correctly (quotes, commas, and newlines).
5. Upload the CSV as a GitHub Actions artifact even if deployment fails, using an `always()`-style finalization step/job.
6. If the run has no selected resources, still create a CSV with headers and no resource rows.
7. Do not create a new Azure module to produce the CSV. Use the workflow/script layer.

## 9. Validation and acceptance criteria

Before considering the work complete, verify all of the following:

- [ ] The naming-standard Markdown includes all 37 requested items, with a pattern and `dev` example.
- [ ] Purpose tokens are documented and are used consistently.
- [ ] Azure-specific naming constraints are checked, including globally unique names and no-hyphen name types.
- [ ] No instance numbering has been introduced.
- [ ] No new Azure resource modules have been created.
- [ ] Existing modules and unrelated workflow stages remain intact.
- [ ] The current `input.json` values for SKU, size, image, region, and other configuration are preserved.
- [ ] The input contains only supported module/resource entries and passes JSON/schema validation.
- [ ] GitHub Environments are named exactly `dev`, `qa`, `uat`, `prod`.
- [ ] Each environment uses its own `AZURE_SUBSCRIPTION_ID`, `AZURE_CLIENT_ID`, and `AZURE_TENANT_ID` secrets.
- [ ] Non-secret variables are documented separately from secrets.
- [ ] The environment-variable Markdown is generated from actual input values and module schemas.
- [ ] VM image variables are separated into `VM_WINDOWS_IMAGE`, `VM_LINUX_IMAGE`, and `VM_WINDOWS_SQL_IMAGE`.
- [ ] PIM is documented accurately and is not conflated with Managed Identity.
- [ ] Reader role configuration is supported only where the current implementation can consume it.
- [ ] Only resources in `input.json` are deployed.
- [ ] Resource deployments run sequentially in a dependency-safe order.
- [ ] The workflow does not queue or execute unrelated modules such as RBAC unless they are explicitly present and selected in the input.
- [ ] A CSV inventory is generated and uploaded at the end of every run, including failed runs.
- [ ] Workflow YAML syntax, JSON syntax, scripts, and module parameter mappings are validated.
- [ ] No secret values appear in logs, generated Markdown, or CSV.

## 10. Expected outputs

Create or update only the files needed to implement the requirements. At minimum, produce:

1. `CLAUDE.md` — this instruction file (keep it at repository root).
2. `docs/resource-naming-standard.md` — complete 37-resource naming catalogue, implementation status, and naming exceptions.
3. `docs/github-environment-variables.md` — generated from the current `input.json` and module schemas.
4. The existing `input.json` — update only if required, preserving existing deployment values and schema compatibility.
5. The existing workflow YAML — change only the deployment selection, environment lookup, sequential execution, and CSV reporting portions needed.
6. A workflow/script-level CSV generation implementation — no new Azure resource module.

At completion, provide a concise change report listing:
- Files inspected.
- Files created/modified.
- Existing modules reused.
- Resource types with no existing module (not implemented).
- Environment secrets and variables required (names only for secrets).
- Deployment ordering strategy and why.
- Validation performed and its results.
- Any unresolved assumptions or missing input values.

**Do not claim that deployments or tests succeeded unless they were actually run and the output confirms success.**
