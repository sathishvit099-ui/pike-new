# ❄️ BIFROST_NEW — PIKE Azure Infrastructure Deployment

![Azure](https://img.shields.io/badge/Cloud-Microsoft%20Azure-0078D4?logo=microsoftazure&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-Bicep-2396D2?logo=azuredevops&logoColor=white)
![Automation](https://img.shields.io/badge/Automation-GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)
![Authentication](https://img.shields.io/badge/Auth-OIDC-6F42C1)
![Shell](https://img.shields.io/badge/Shell-PowerShell-5391FE?logo=powershell&logoColor=white)
![Environment](https://img.shields.io/badge/Environment-dev-orange)
![Status](https://img.shields.io/badge/Workflow-manual%20dispatch-lightgrey)

> **BIFROST_NEW** is a JSON-driven Azure Infrastructure as Code repository for the PIKE workload. It combines GitHub Actions, PowerShell, Azure CLI, reusable Bicep modules and Microsoft Entra workload identity federation (OIDC) to deploy configured Azure resources.

---

## 📚 Table of contents

- [🏗️ Architecture at a glance](#️-architecture-at-a-glance)
- [📁 Repository structure](#-repository-structure)
- [⚙️ Configuration with inputjson](#️-configuration-with-inputjson)
- [🧩 Bicep module catalogue](#-bicep-module-catalogue)
- [🚀 GitHub Actions workflow](#-github-actions-workflow)
  - [Resource dependencies](#resource-dependencies)
- [🔐 Authentication and secrets](#-authentication-and-secrets)
- [🔄 Deployment lifecycle](#-deployment-lifecycle)
- [🧪 Validation and deployment behaviour](#-validation-and-deployment-behaviour)
- [📦 GitHub Actions artifacts and validation reports](#-github-actions-artifacts-and-validation-reports)
- [🏷️ Resource naming](#️-resource-naming)
- [🛡️ Security and operational notes](#️-security-and-operational-notes)
- [▶️ Running the workflow](#️-running-the-workflow)
- [🧭 Current limitations and next steps](#-current-limitations-and-next-steps)

---

## 🏗️ Architecture at a glance

The repository follows a configuration-driven, modular deployment approach:

- **Configuration:** `input.json` describes the environment, request metadata, subscription placeholder, deployment location and resource collections.
- **Orchestration:** `.github/workflows/deploy.yml` coordinates validation, authentication and resource deployment.
- **Execution:** PowerShell reads JSON objects, maps their properties to Bicep parameters and writes temporary ARM deployment parameter files.
- **Infrastructure:** Individual Bicep modules define Azure resources.
- **Authentication:** GitHub Actions obtains an OIDC token and authenticates to Azure using `azure/login@v2`.

### High-level architecture

```mermaid
flowchart TB
    subgraph CFG["📝 Configuration layer"]
      direction TB
      JSON["input.json"]
    end

    subgraph CICD["⚙️ CI/CD orchestration layer"]
      direction TB
      GH["GitHub Actions<br/>workflow_dispatch"]
      PRE["Prechecks<br/>PowerShell + Azure CLI + Bicep"]
      AUTH["Azure OIDC login<br/>azure/login@v2"]
      PS["PowerShell orchestration<br/>JSON → ARM parameters"]
    end

    subgraph IaC["🧩 Infrastructure layer"]
      direction TB
      MOD["Reusable Bicep modules"]
      WHATIF["Azure deployment What-If"]
      DEPLOY["Azure deployment create"]
    end

    subgraph AZ["☁️ Microsoft Azure"]
      direction TB
      SUB["Target subscription"]
      RES["Resource groups and Azure resources"]
    end

    JSON --> GH
    GH --> PRE --> AUTH --> PS
    JSON --> PS
    PS --> MOD --> WHATIF --> DEPLOY
    AUTH -. authenticated context .-> SUB
    DEPLOY --> SUB --> RES

    classDef config fill:#163A5F,stroke:#4EA5D9,color:#FFFFFF,stroke-width:2px
    classDef orchestration fill:#51356D,stroke:#B58AD6,color:#FFFFFF,stroke-width:2px
    classDef iac fill:#145A43,stroke:#58C99A,color:#FFFFFF,stroke-width:2px
    classDef azure fill:#7A4B12,stroke:#E6A23C,color:#FFFFFF,stroke-width:2px

    class JSON config
    class GH,PRE,AUTH,PS orchestration
    class MOD,WHATIF,DEPLOY iac
    class SUB,RES azure
```

### Scope model

| Deployment | Azure deployment scope | Module |
|---|---|---|
| Resource group | Subscription | `modules/RG/resourcegroup.bicep` |
| NSG, route table, VNet, subnet | Resource group | `modules/networking/*.bicep` |
| Key Vault | Resource group | `modules/security/keyvault.bicep` |
| Storage account and blob resources | Resource group | `modules/storage/storageAccount.bicep` |
| SQL server and database | Resource group | `modules/database/sql.bicep` |
| Azure OpenAI account | Resource group | `modules/ai/openai.bicep` |
| VM and NIC | Resource group | `modules/compute/vm.bicep` |

---

## 📁 Repository structure

The current `main` branch is organised as follows:

```text
BIFROST_NEW/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── modules/
│   ├── RG/
│   │   └── resourcegroup.bicep
│   ├── ai/
│   │   └── openai.bicep
│   ├── compute/
│   │   └── vm.bicep
│   ├── database/
│   │   └── sql.bicep
│   ├── networking/
│   │   ├── nsg.bicep
│   │   ├── routetable.bicep
│   │   ├── subnet.bicep
│   │   └── vnet.bicep
│   ├── security/
│   │   └── keyvault.bicep
│   └── storage/
│       └── storageAccount.bicep
├── input.json
└── README.md
```

> ℹ️ The workflow and module paths above reflect the repository's current `main` branch. There is currently no `modules/main.bicep`, `environments/` directory, `.bicepparam` file or `config/subscriptions.json` in this branch. The deployment is driven by `input.json` and individual module files.

---

## ⚙️ Configuration with `input.json`

`input.json` is the deployment configuration feed. The workflow reads the JSON and selects the relevant collection under `landingZones`.

### Top-level structure

| Property | Purpose |
|---|---|
| `environment` | Environment selector; current workflow accepts `dev` only |
| `request` | Ticket, requester, approval and project metadata |
| `subscription` | Subscription name and a subscription-ID placeholder |
| `deployment` | Deployment-level location |
| `landingZones` | Arrays containing resource configuration objects |

### Current resource collections

The checked-in sample currently has one configured object in each of these ten collections:

| JSON collection | Resource type |
|---|---|
| `resourceGroups` | Resource groups |
| `vnets` | Virtual networks |
| `subnets` | Subnets |
| `nsgs` | Network security groups |
| `routeTables` | Route tables |
| `vms` | Windows virtual machines |
| `keyVaults` | Key Vaults |
| `storageAccounts` | Storage accounts and configured blob containers |
| `sqlDatabases` | SQL logical servers and databases |
| `openAiServices` | Azure OpenAI accounts |

### How a JSON object becomes a deployment

For each configured object, the workflow:

1. Reads the object from its `landingZones` array.
2. Maps JSON fields to the corresponding Bicep module parameters.
3. Creates a temporary ARM parameter JSON file under `$env:RUNNER_TEMP`.
4. Runs `az deployment group what-if` (or subscription What-If for resource groups).
5. Runs the matching `az deployment ... create` command if What-If succeeds.

```mermaid
flowchart LR
    subgraph INPUT["📝 Input"]
      A["landingZones.keyVaults[]"]
    end
    subgraph MAP["🔧 Parameter mapping"]
      B["PowerShell reads object"]
      C["Maps name, location, SKU,<br/>network and security settings"]
      D["Writes temporary kv.json"]
    end
    subgraph EXEC["🚀 Deployment"]
      E["Bicep What-If"]
      F["Bicep deployment"]
    end
    A --> B --> C --> D --> E --> F

    classDef input fill:#163A5F,stroke:#4EA5D9,color:#fff
    classDef mapping fill:#51356D,stroke:#B58AD6,color:#fff
    classDef execution fill:#145A43,stroke:#58C99A,color:#fff
    class A input
    class B,C,D mapping
    class E,F execution
```

**Adding another instance:** add another object to the appropriate array and provide all required properties. Ensure referenced resources exist and that names such as `resourceGroupName`, `vnetName`, `subnetName`, `networkSecurityGroupName` and `routeTableName` match the intended resources. The workflow loops over the configured arrays.

---

## 🧩 Bicep module catalogue

Modules are kept separate by Azure resource responsibility. They accept parameters rather than reading `input.json` directly.

| Module | Main responsibility | Notable behaviour |
|---|---|---|
| `RG/resourcegroup.bicep` | Resource group | Subscription-scope resource |
| `networking/nsg.bicep` | Network security group | Builds security rules from an array |
| `networking/routetable.bicep` | Route table | Builds routes from an array |
| `networking/vnet.bicep` | Virtual network | Accepts address prefixes and DNS settings |
| `networking/subnet.bicep` | Subnet | References an existing VNet; optionally associates NSG and route table |
| `security/keyvault.bicep` | Key Vault | Supports RBAC authorization, purge protection and soft-delete retention |
| `storage/storageAccount.bicep` | Storage account | Creates blob service and configured containers |
| `database/sql.bicep` | SQL server and database | Uses a secure administrator password parameter |
| `ai/openai.bicep` | Azure OpenAI | Configures account SKU, custom subdomain and public network access |
| `compute/vm.bicep` | Windows VM and NIC | References an existing VNet/subnet and creates a NIC |

### Module design principles

- 📦 One module per resource responsibility.
- 🔁 Parameter-driven configuration to support multiple instances.
- 🔐 Sensitive password parameters use Bicep `@secure()`.
- 📤 Modules expose useful resource IDs and names through outputs.
- 🧱 Existing-resource references are used where a module depends on infrastructure created elsewhere (for example, VM networking).
- 🏷️ Tags and location are supplied from the configuration object where supported.

---

## 🚀 GitHub Actions workflow

**Workflow file:** `.github/workflows/deploy.yml`

**Workflow name:** `PIKE Modular Azure Infrastructure Deployment`

**Trigger:** Manual `workflow_dispatch`

**Runner:** `[self-hosted, X64, Windows]`

**Permissions:**

- `contents: read` — checkout repository content.
- `id-token: write` — request the GitHub OIDC token used for Azure login.

### Job sequence (dynamic sequential plan)

```mermaid
flowchart TD
    A["workflow_dispatch"] --> B["prechecks<br/>validate-workflows.yml"]
    B --> C["plan<br/>read input.json, build ordered plan"]
    C --> D["context<br/>Azure OIDC login, subscription check, RG name"]
    D --> E["deploy<br/>ONE job, walks the plan one entry at a time"]
    E --> F["access-management<br/>access.yml (RBAC / PIM)"]
    F --> G["inventory<br/>CSV artifact, always runs"]

    classDef start fill:#163A5F,stroke:#4EA5D9,color:#fff
    classDef validation fill:#51356D,stroke:#B58AD6,color:#fff
    classDef deploy fill:#145A43,stroke:#58C99A,color:#fff
    classDef report fill:#7A4B12,stroke:#E6A23C,color:#fff
    class A start
    class B,C,D validation
    class E,F deploy
    class G report
```

The workflow deploys **only** the resources set to `"yes"` in `input.json`, plus the prerequisites they need. Resources that are not in the plan do not appear in the run at all. Deployments never run in parallel.

**Example:** an `input.json` with only `"storageAccount": "yes"` produces this plan:

```text
1. Resource Group     (prerequisite of storageAccount, added automatically)
2. Storage Account    (requested in input.json)
```

The plan, with the reason for each entry, is shown in the run summary of the `plan` job.

### Job responsibilities

| Job | Responsibility |
|---|---|
| `prechecks` | Calls `validate-workflows.yml`: Bicep build, actionlint, zizmor and `input.json` structure checks |
| `plan` | Validates `input.json`, adds required prerequisites and outputs the ordered deployment plan |
| `context` | Logs in with OIDC, verifies the subscription, checks `RESOURCE_TAGS` and resolves the resource group name |
| `deploy` | Deploys each plan entry in order through `.github/actions/deploy-bicep` (validate parameters → What-If → deploy) |
| `access-management` | Runs `access.yml` for RBAC / PIM requests, after the deployment plan |
| `inventory` | Builds `artifacts/deployment-inventory-<run-id>.csv` from the plan results and uploads it, even on failure |

### Resource dependencies

Every resource needs the resource group. The table shows the full chain each resource needs. Missing prerequisites are added to the plan automatically.

| Resource (`resourceTargets` key) | Required chain (deployed in this order) | What the module looks up |
|---|---|---|
| Resource Group (`resourceGroup`) | — | — |
| NSG (`networkSecurityGroup`) | RG | — |
| Route Table (`routeTable`) | RG | — |
| Virtual Network (`virtualNetwork`) | RG | — |
| Subnet (`subnet`) | RG → VNet | `vnet-pike-<env>` |
| App Gateway Subnet (`applicationGatewaySubnet`) | RG → VNet | `vnet-pike-<env>` |
| Load Balancer (`loadBalancer`) | RG → VNet → Subnet | subnet `snet-<purpose>` (private frontend IP) |
| Application Gateway (`applicationGateway`) | RG → VNet → App Gateway Subnet | subnet `snet-<purpose>-agw` |
| VM Windows / Linux / Windows-SQL (`vmWindows`, `vmLinux`, `vmWindowsSql`) | RG → VNet → Subnet | VNet + subnet `snet-<purpose>` for the NIC |
| PostgreSQL (`postgresql`) | RG → VNet | VNet only; the module creates its own subnet `snet-<purpose>-psql` |
| Key Vault (`keyVault`) | RG | — |
| Storage Account (`storageAccount`) | RG | — |
| Azure SQL (`sqlDatabase`) | RG | — |
| Azure OpenAI (`openAi`) | RG | — |

**Optional links.** These are used only when that resource is also `"yes"`:

| Resource | Optional | Effect |
|---|---|---|
| Subnet | NSG | The NSG is deployed first and associated with the subnet, so it filters the VMs and load balancer in that subnet |
| Subnet | Route Table | The route table is deployed first and associated with the subnet |

> ℹ️ A VM does **not** require an NSG. The VM's NIC has no NSG of its own; NSG protection comes from the subnet. For a VM behind an NSG, set `networkSecurityGroup`, `subnet` and the VM to `"yes"`. The plan becomes RG → NSG → VNet → Subnet (NSG attached) → VM.

**Created inside a module** (not separate `input.json` entries):

| Module | Also creates |
|---|---|
| VM | Network interface `nic-<vm name>` (private IP only) |
| Application Gateway | Public IP `pip-agw-pike-<env>` |
| PostgreSQL | Delegated subnet, private DNS zone and VNet link |

**Access requests** are not added to the plan automatically:

| Request | Needs |
|---|---|
| RBAC with `RBAC_SCOPE=resourceGroup` | RG must exist (set `resourceGroup: "yes"` or create it earlier) |
| RBAC with `RBAC_SCOPE=storageAccount` | RG and Storage Account must exist |
| RBAC with `RBAC_SCOPE=subscription`, or PIM | Nothing |

### Prerequisite handling rules

- An **auto-added** prerequisite (one that is not `"yes"` in `input.json`) is created **only if it does not exist**. If What-If shows that it already exists, it is reported as `Skipped` and not re-applied, so existing configuration (for example an NSG already attached to a subnet) is never changed.
- The **resource group** is always applied, because re-applying it is idempotent (same name, location and tags).
- An existing **VNet** is never re-applied, even when it is requested, so subnets created later are not removed.
- If an entry **fails**, every entry that depends on it is skipped and independent entries still run. The run is marked failed if anything failed or was blocked.
- The Azure OIDC login is refreshed before each entry, so a long plan does not outlive the Azure CLI token.

### Where these rules live in the code

| What | Location |
|---|---|
| Dependency table (`CATALOG`): `requires` = required prerequisites, `after` = optional ordering links, list order = deployment order | `.github/workflows/deploy.yml` → `plan` job, `const CATALOG = [...]` |
| Subnet attaches the NSG / route table only when they are `"yes"` | `CATALOG` → `subnet` entry (`attachNetworkSecurityGroup`, `attachRouteTable`) |
| Self-check: a prerequisite must be listed before the resource that needs it | `plan` job, the "Self-check" block after `CATALOG` |
| Adding missing prerequisites (transitively) | `plan` job, the `const reason = {}` loop |
| "Create only if missing" for auto-added entries | `plan` job, `skipIfExistsType:` |
| Recording each entry's dependencies | `plan` job, `dependsOn:` |
| Skipping an entry whose prerequisite failed | `.github/actions/deploy-bicep/action.yml`, `badPrereqs` |
| Skipping a resource that already exists (What-If) | `.github/actions/deploy-bicep/action.yml`, the `skipIfExistsType` check |
| Job-level conditions (`deploy` runs only if the plan is not empty, `access-management` is blocked if the RG failed, `inventory` always runs) | `.github/workflows/deploy.yml`, the `if:` of each job |

**To change a dependency**, edit that resource's `requires` list in `CATALOG`. **To add a resource type**, add a `CATALOG` entry for an existing module at the right point in dependency order, and add the same key to `resourceTargets` in `input.json` and to the target list in `validate-workflows.yml`.

---

## 🔐 Authentication and secrets

Azure authentication uses GitHub Actions OIDC through `azure/login@v2`. This avoids storing a client secret for the GitHub-to-Azure authentication flow.

Configure the following secrets in the GitHub Environment named by `input.json` → `environment` (for example `dev`). All non-secret values (SKUs, sizes, images, CIDRs, naming tokens and tags) are GitHub Environment **variables** in that same environment. `input.json` contains only yes/no flags. See [docs/github-environment-variables.md](docs/github-environment-variables.md) for every key and its `dev` value.

| Secret | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | Microsoft Entra application/service principal client ID |
| `AZURE_TENANT_ID` | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription GUID |
| `VM_ADMIN_PASSWORD` | Windows VM local administrator password |
| `SQL_ADMIN_PASSWORD` | SQL administrator password |
| `POSTGRESQL_ADMIN_PASSWORD` | PostgreSQL Flexible Server administrator password (required when `postgresqlServers` is in `input.json`) |

### OIDC trust prerequisites

1. Configure a federated identity credential on the Microsoft Entra application/service principal.
2. Ensure its issuer, subject and audience match the GitHub Actions OIDC identity for this repository and the `dev` environment.
3. Grant the service principal the Azure permissions required to create the configured resources at the relevant scopes.
4. Ensure the GitHub Actions environment and required secrets are available to the workflow.

> 🔒 Never commit administrator passwords, client secrets, certificates or other credentials to `input.json`, Bicep files or the repository.

### Subscription ID source

The workflow uses `secrets.AZURE_SUBSCRIPTION_ID` for Azure login and subscription selection. The `subscription.subscriptionId` value in `input.json` is currently a literal placeholder (`${AZURE_SUBSCRIPTION_ID}`); GitHub Actions does not automatically expand environment variables inside JSON. Do not treat that JSON property as the active authentication source.

---

## 🔄 Deployment lifecycle

Each resource deployment follows a preview-then-deploy pattern:

```mermaid
flowchart TD
    A["Read resource object from input.json"] --> B["Build parameter map"]
    B --> C["Write temporary ARM parameters file"]
    C --> D["Run Azure What-If"]
    D --> E{"What-If succeeded?"}
    E -- "Yes" --> F["Run Azure deployment create"]
    E -- "No" --> G["Job/step fails"]
    F --> H{"Deployment succeeded?"}
    H -- "Yes" --> I["Resource deployment completed"]
    H -- "No" --> J["Job/step fails"]

    subgraph PREP["📝 Preparation"]
      A
      B
      C
    end
    subgraph PREVIEW["🔍 Preview"]
      D
      E
    end
    subgraph APPLY["🚀 Apply"]
      F
      H
      I
      G
      J
    end

    classDef prep fill:#163A5F,stroke:#4EA5D9,color:#fff
    classDef preview fill:#7A4B12,stroke:#E6A23C,color:#fff
    classDef apply fill:#145A43,stroke:#58C99A,color:#fff
    class A,B,C prep
    class D,E preview
    class F,G,H,I,J apply
```

Temporary parameter files are written under the runner's `RUNNER_TEMP` directory. Passwords for the VM and SQL modules are supplied from GitHub secrets as secure Bicep parameters rather than being added to the ordinary JSON parameter object.

---

## 🧪 Validation and deployment behaviour

### Current prechecks

The `prechecks` job currently:

- Checks Azure CLI at `C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd`.
- Installs and upgrades Bicep, then prints its version.
- Checks that VM and SQL passwords and the subscription ID secret are present.
- Checks the subscription ID has GUID format without printing its value.
- Builds every `.bicep` file found under `modules/`.
- Parses `input.json` and checks the environment is `dev`.
- Checks that the resource-group collection is non-empty and the expected resource collections are present.

> ℹ️ Although the job is named “Bicep lint and input validation”, the current workflow runs Bicep **build** commands; it does not currently invoke a separate `az bicep lint` command. JSON validation currently checks required top-level collections, not every field, type, naming rule or cross-resource reference.

### Current failure behaviour

The `deploy` job walks the plan in order. When an entry fails, the entries that depend on it are skipped (`Skipped`, naming the failed prerequisite) and independent entries continue. The run fails if any entry failed or was blocked.

Every run ends with the `inventory` job. It uploads a CSV with one row per plan entry, showing its status (`Succeeded`, `Skipped` or `Failed`) and why it was in the plan.

### Existing-resource handling

The VNet is never re-applied when it already exists, so subnets created later are not removed. Prerequisites that were added automatically are created only when they are missing. See [Prerequisite handling rules](#prerequisite-handling-rules).

---

## 📦 GitHub Actions artifacts and validation reports

The repository is configured to generate **two separate GitHub Actions artifacts**, each containing an Excel workbook with validation or access findings.

| # | Artifact | Workflow | Excel file | Contents |
|---:|---|---|---|---|
| 1 | `PIKE-Validation-${{ github.run_id }}` | `.github/workflows/validate-workflows.yml` | `pike-validation-report.xlsx` | **YAML Validation** worksheet with actionlint and zizmor findings; **Bicep Validation** worksheet with findings reported separately for each `.bicep` file. |
| 2 | `PIKE-Access-Results-${{ github.run_id }}` | `.github/workflows/access.yml` | `pike-access-results.xlsx` | Separate **RBAC** and **PIM** worksheets containing access request/assignment results and errors. |

### Where to download the artifacts

1. Open the repository's **Actions** tab.
2. Select the relevant workflow run.
3. Open the completed run summary.
4. Find the **Artifacts** section and download the required report.

Both artifact upload steps are configured with a **30-day retention period**.

> **Note:** These are two artifact types defined by the workflows. A run produces an artifact only when its workflow reaches the corresponding upload step. The validation report is uploaded even when its validation checks fail, provided report generation succeeds.

---

## 🏷️ Resource naming

The Key Vault, Storage Account and Azure OpenAI modules append a deterministic five-character suffix generated with Bicep `uniqueString()` to a truncated input name.

| Resource | Current module naming behaviour |
|---|---|
| Key Vault | Up to 15 characters from the input name + 5-character suffix |
| Storage account | Up to 19 characters from the input name + 5-character suffix |
| Azure OpenAI account | Up to 20 characters from the input name + 5-character suffix |
| Azure OpenAI custom subdomain | Passed through as configured; no suffix is appended by this module |

The suffix is deterministic for the same subscription, resource group and input name. It is not a random value and is not based on the GitHub Actions run ID.

**Important:** The actual deployed name for these resources may differ from the name in `input.json`. Any later verification or resource-reference logic must account for the final name emitted by the module, rather than assuming the configured input name is the deployed name.

Storage account names must satisfy Azure's lowercase alphanumeric and 3–24 character constraints. Key Vault names must satisfy Azure's 3–24 character constraints. Azure OpenAI account and custom subdomain naming/availability constraints must also be checked for the selected service and region.

---

## 🛡️ Security and operational notes

- 🔐 Keep credentials in GitHub Actions secrets; do not put them in JSON or source files.
- 🪪 Use OIDC federation for GitHub-to-Azure authentication and grant least-privilege Azure RBAC permissions.
- 🧪 Review What-If output before applying infrastructure changes.
- 🌐 The sample NSG has no inbound security rules. The sample VM has no public IP; configure an approved private access path before attempting remote administration.
- 🗄️ The sample SQL configuration disables public network access. Provide an appropriate private connectivity design if clients need to connect.
- 🏷️ Keep resource tags consistent across resource collections.
- 🧾 Treat the input JSON as deployment intent, not proof that a resource was successfully provisioned.
- 🔎 Confirm resource names, region, SKU availability, quota and subscription permissions before running a deployment.

---

## ▶️ Running the workflow

1. Open the repository in GitHub.
2. Review `input.json` and confirm the requested resources, names, locations, tags and cross-resource references.
3. Confirm the `dev` GitHub environment and required secrets are configured.
4. Confirm the Windows self-hosted runner is online and has Azure CLI installed at the path expected by the workflow.
5. Open **Actions** → **PIKE Modular Azure Infrastructure Deployment**.
6. Select **Run workflow** and start the workflow from the intended branch.
7. Review precheck output, Azure login output and each What-If/deployment result.
8. Verify deployed resources in Azure before treating the request as complete.

### Local Bicep build

From a PowerShell terminal at the repository root:

```powershell
$ErrorActionPreference = 'Stop'
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

& $az bicep build --file modules/RG/resourcegroup.bicep --stdout
if ($LASTEXITCODE -ne 0) { throw 'Bicep build failed.' }

Get-ChildItem modules -Recurse -Filter '*.bicep' | ForEach-Object {
    & $az bicep build --file $_.FullName --stdout | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Bicep build failed: $($_.FullName)" }
}
```

This validates Bicep compilation only; it does not authenticate to Azure or deploy resources.

---

## 🧭 Current limitations and next steps

The following are known gaps in the current implementation, not claims that the functionality is already available.

| Area | Current state | Potential next improvement |
|---|---|---|
| Failure isolation | Sequential jobs; a failure can skip downstream jobs | Allow independent resource deployments to continue where dependencies permit |
| Per-resource result tracking | No active consolidated result collector | Track requested, deployed, failed and skipped resources individually |
| Final verification | Verification block is commented out | Activate verification with dependency-aware execution |
| Deployment artifact | No active final report artifact | Generate and upload a JSON/CSV/Markdown deployment summary |
| Input validation | Basic structure checks | Validate object properties, types, allowed values, naming and references |
| Bicep linting | Build is executed; separate lint is absent | Add `az bicep lint` and enforce lint results |
| Resource naming | Some modules transform input names | Capture and consistently use actual deployed names |
| Documentation | This README documents the current checked-in implementation | Keep it updated whenever workflow or module behaviour changes |

### 🎯 Intended future reporting model

The desired report should include every resource requested in `input.json`, including resources that were not deployed.

| Report field | Description |
|---|---|
| Resource type | Azure resource category |
| Requested name | Name supplied in `input.json` |
| Actual name | Final Azure resource name, when known |
| Resource group | Target resource group |
| Status | Deployed, Failed or Skipped |
| Stage | Workflow deployment stage |
| Error/reason | Failure detail or skip reason |
| Timestamp | Deployment/verification time |

> A future resilient orchestration design should distinguish **independent resources** from **resources with dependencies**. 
> For example, a VM depends on its NIC and subnet being available; a subnet may depend on its VNet, NSG and route table.
> A failure should not stop unrelated resources from being attempted, but dependent resources should be marked skipped with a clear reason when their prerequisites are unavailable.
---

```mermaid
%% Generated by https://gitdiagram.com/prometheus-n/pike_infra_eaas
flowchart TD

subgraph group_deploy["Deployment"]
  node_environment["Environment input<br/>[input.json]"]
  node_workflow["Deployment workflow<br/>[deploy.yml]"]
end

subgraph group_foundation["Foundation and access"]
  node_resourcegroup["Resource groups"]
  node_rbac["RBAC assignments"]
end

subgraph group_network["Networking"]
  node_vnet["Virtual network<br/>[vnet.bicep]"]
  node_subnet["Subnets<br/>[subnet.bicep]"]
  node_appgwsubnet["Gateway subnet"]
  node_nsg["Network security groups<br/>[nsg.bicep]"]
  node_routes["Route tables<br/>[routetable.bicep]"]
  node_loadbalancer["Load balancer<br/>[lb.bicep]"]
  node_appgateway["Application gateway"]
end

subgraph group_workloads["Workloads"]
  node_vm["Virtual machines<br/>[vm.bicep]"]
  node_sql["SQL database<br/>[sql.bicep]"]
end

subgraph group_services["Platform services"]
  node_storage["Storage account"]
  node_keyvault["Key Vault<br/>[keyvault.bicep]"]
  node_openai["Azure OpenAI<br/>[openai.bicep]"]
end

node_operator(("Operator"))
node_azure["Azure subscription"]

node_operator -->|"reviews"| node_environment
node_operator -->|"manually triggers"| node_workflow
node_workflow -.->|"uses configuration"| node_environment
node_workflow -->|"runs What-If and deploys"| node_azure
node_workflow -.->|"deploys modules"| node_resourcegroup
node_workflow -.->|"deploys modules"| node_rbac
node_workflow -.->|"deploys modules"| node_vnet
node_workflow -.->|"deploys modules"| node_subnet
node_workflow -.->|"deploys modules"| node_appgwsubnet
node_workflow -.->|"deploys modules"| node_nsg
node_workflow -.->|"deploys modules"| node_routes
node_workflow -.->|"deploys modules"| node_loadbalancer
node_workflow -.->|"deploys modules"| node_appgateway
node_workflow -.->|"deploys modules"| node_vm
node_workflow -.->|"deploys modules"| node_sql
node_workflow -.->|"deploys modules"| node_storage
node_workflow -.->|"deploys modules"| node_keyvault
node_workflow -.->|"deploys modules"| node_openai

click node_environment "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/input.json"
click node_workflow "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/.github/workflows/deploy.yml"
click node_resourcegroup "https://github.com/prometheus-n/pike_infra_eaas/tree/dev/modules/RG"
click node_rbac "https://github.com/prometheus-n/pike_infra_eaas/tree/dev/modules/RBAC"
click node_vnet "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/networking/vnet.bicep"
click node_subnet "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/networking/subnet.bicep"
click node_appgwsubnet "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/networking/applicationGatewaySubnet.bicep"
click node_nsg "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/networking/nsg.bicep"
click node_routes "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/networking/routetable.bicep"
click node_loadbalancer "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/loadbalancer/lb.bicep"
click node_appgateway "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/networking/applicationGateway.bicep"
click node_vm "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/compute/vm.bicep"
click node_sql "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/database/sql.bicep"
click node_storage "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/storage/storageAccount.bicep"
click node_keyvault "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/security/keyvault.bicep"
click node_openai "https://github.com/prometheus-n/pike_infra_eaas/blob/dev/modules/ai/openai.bicep"

classDef toneNeutral fill:#f8fafc,stroke:#334155,stroke-width:1.5px,color:#0f172a
classDef toneBlue fill:#dbeafe,stroke:#2563eb,stroke-width:1.5px,color:#172554
classDef toneAmber fill:#fef3c7,stroke:#d97706,stroke-width:1.5px,color:#78350f
classDef toneMint fill:#dcfce7,stroke:#16a34a,stroke-width:1.5px,color:#14532d
classDef toneRose fill:#ffe4e6,stroke:#e11d48,stroke-width:1.5px,color:#881337
classDef toneIndigo fill:#e0e7ff,stroke:#4f46e5,stroke-width:1.5px,color:#312e81
classDef toneTeal fill:#ccfbf1,stroke:#0f766e,stroke-width:1.5px,color:#134e4a
class node_environment,node_workflow toneBlue
class node_resourcegroup,node_rbac toneAmber
class node_vnet,node_subnet,node_appgwsubnet,node_nsg,node_routes,node_loadbalancer,node_appgateway toneMint
class node_vm,node_sql toneRose
class node_storage,node_keyvault,node_openai,node_operator,node_azure toneIndigo
```
---

<p align="center">
  **❄️ BIFROST_NEW | PIKE Infrastructure as Code**
  <br/>
  <sub>Configuration-driven • Modular Bicep • OIDC-authenticated • Azure-native</sub>
</p>
