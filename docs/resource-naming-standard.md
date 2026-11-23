# Pike Resource Naming — How Names Are Built

Resource names are **defined inside each Bicep module**. A module receives naming tokens as parameters and builds the name itself, for example:

```bicep
var keyVaultName = 'kv-pike-${purpose}-${environmentName}'
```

The workflows never write out a full name. They pass only the token values, which come from `input.json` → `target`:

| Token | `input.json` key | Current value |
|---|---|---|
| `<env>` | `environment` | `dev` |
| `<workload>` | `target.workload` | `platform-svc` |
| `<system>` | `target.system` | `sap` |
| `<purpose>` | `target.purpose` | `app` (one purpose for the whole deployment; 2-11 lowercase letters/digits) |

## 1. Rules (from the Pike naming sheet)

- **Pattern:** one pattern for every resource: lowercase, hyphenated, environment last.
- **Tokens:**
  - `<env>` = `dev` | `qa` | `uat` | `prod`
  - `<workload>` = `int-<system>-<entity>` | `app-<name>` | `platform-svc` | `shared-infra`
  - `<system>` = source/target system (`sap`, `okta`, `fleet` …)
  - `<domain>` = business area (`hr`, `finance`, `ops` …)
- **Region code:** goes before `<env>` only if the deployment is multi-region. This is *not used*, because the deployment is single-region.
- **Globally unique names** (storage, Key Vault, registry, PostgreSQL, APIM) include `pike`. There is no random suffix, so names are identical on every run.
- **Length limits:** storage ≤ 24 characters, with no spaces, no hyphens and all lowercase; Key Vault ≤ 24; Container App ≤ 32.
- **Required tags:** `env`, `workload`, `owner`, `cost-center`, `data-class`. Every module adds `env` and `workload`. The other three come from the `RESOURCE_TAGS` variable, and the run fails if any of them is missing.

### Validation before deployment

- **`input.json`:** the `plan` job checks that `environment` is one of the four values and that every target is `yes` or `no`.
- **Workload and tags:** the `plan` job checks `input.json` → `target` (workload format, system, location); the `context` job checks the required tags.
- **Naming tokens:** `.github/actions/deploy-bicep` checks every token for lowercase letters/digits with single hyphens. `target.purpose` must be 2-11 lowercase letters/digits (no spaces, no hyphens), because it is part of the Key Vault and storage account names.
- **Module rules:** the same action also checks each module's own allowed values and minimum/maximum lengths before calling Azure.

## 2. Names built by the existing modules

| Resource | Module (where the name is defined) | Pattern | `dev` example | Pattern source |
|---|---|---|---|---|
| Resource group | `modules/RG/resourcegroup.bicep` | `rg-<workload>-<env>` | `rg-platform-svc-dev` | Pike sheet |
| Virtual network | `modules/networking/vnet.bicep` | `vnet-pike-<env>` | `vnet-pike-dev` | Pike sheet |
| Subnet | `modules/networking/subnet.bicep` | `snet-<purpose>` | `snet-app` | Pike sheet |
| Application Gateway subnet | `modules/networking/applicationGatewaySubnet.bicep` | `snet-<purpose>-agw` | `snet-app-agw` | Pike sheet |
| Application Gateway | `modules/networking/applicationGateway.bicep` | `agw-pike-<env>` (public IP `pip-agw-pike-<env>`) | `agw-pike-dev` | Pike sheet |
| Key Vault | `modules/security/keyvault.bicep` | `kv-pike-<purpose>-<env>` | `kv-pike-app-dev` | Pike sheet |
| Storage account | `modules/storage/storageAccount.bicep` | `stpike<purpose><env>` | `stpikeappdev` | Pike sheet |
| PostgreSQL server | `modules/database/postgresql.bicep` | `psql-pike-<purpose>-<env>` (delegated subnet `snet-<purpose>-psql`) | `psql-pike-app-dev` | Pike sheet |
| Azure SQL (apps) | `modules/database/sql.bicep` | `sql-<workload>-<env>`; database `<purpose>` | `sql-platform-svc-dev` / `app` | Pike sheet |
| Network security group | `modules/networking/nsg.bicep` | `nsg-pike-<purpose>-<env>` | `nsg-pike-app-dev` | CLAUDE.md (not on the sheet) |
| Route table | `modules/networking/routetable.bicep` | `rt-pike-<purpose>-<env>` | `rt-pike-app-dev` | CLAUDE.md (not on the sheet) |
| Load balancer | `modules/loadbalancer/lb.bicep` | `lb-pike-<purpose>-<env>` | `lb-pike-app-dev` | CLAUDE.md (not on the sheet) |
| Azure OpenAI | `modules/ai/openai.bicep` | `oai-pike-<purpose>-<env>` | `oai-pike-app-dev` | CLAUDE.md, without the random suffix |
| VM — Windows | `modules/compute/vm.bicep` (`vmType=windows`) | `vm-pike-<system>-<purpose>-win-<env>` | `vm-pike-sap-app-win-dev` | CLAUDE.md |
| VM — Linux | `modules/compute/vm.bicep` (`vmType=linux`) | `vm-pike-<system>-<purpose>-lnx-<env>` | `vm-pike-sap-app-lnx-dev` | CLAUDE.md |
| VM — Windows + SQL image | `modules/compute/vm.bicep` (`vmType=windows-sql`) | `vm-pike-<system>-<purpose>-sql-<env>` | `vm-pike-sap-app-sql-dev` | CLAUDE.md |
| RBAC assignment | `modules/access/rbac/*.bicep` | GUID derived from scope + principal + role | — | Azure requirement |
| PIM eligibility request | `modules/access/pim/pim.bicep` | GUID derived from principal + role + start time | — | Azure requirement |

Sub-resources follow their parent: a VM NIC is `nic-<vm name>`. The Windows computer name is the first 15 characters of `<system><purpose><os><env>`. The PostgreSQL private DNS link is `link-vnet-pike-<env>`. The `-agw` and `-psql` suffixes keep the role-specific subnets separate from the main `snet-<purpose>` subnet, because the whole deployment shares one purpose.

## 3. Resource types on the sheet or in CLAUDE.md with no module

No modules were created for these. They are **not currently implemented**.

| Resource | Pattern (Pike sheet / CLAUDE.md) |
|---|---|
| Subscription | `sub-pike-acs-<env>` |
| Container Apps environment / app / job | `cae-pike-<env>` / `ca-<workload>[-<role>]-<env>` / `caj-<workload>-<job>-<env>` |
| Container registry | `crpike<purpose>` |
| Managed identity | `id-<workload>-<env>` |
| Service Bus namespace / queue / topic / subscription | `sbns-pike-<env>` / `q-<system>-<entity>` / `sbt-<domain>-<event>` / `sbs-<target>` |
| Event Grid / Event Hubs | `egns-pike-<env>` / `evhns-pike-<env>` |
| API Management | `apim-pike-<env>` / `<domain>-api` |
| Front Door | `afd-pike-<env>` |
| Log Analytics / App Insights | `log-pike-<env>` / `appi-<workload>-<env>` |
| Bastion, DNS zone, Private Endpoint, Cosmos DB, AKS, App Service, Logic App, Function App, Redis, VPN Gateway, Data Lake Gen2, Power BI, Fabric, ACS | See CLAUDE.md section 3 |

