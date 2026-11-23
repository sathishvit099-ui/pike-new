# GitHub Environment `dev` — Secrets and Variables

`input.json` contains the target environment, the deployment target (`workload`, `system`, `purpose`, `location`), a `yes`/`no` for each resource type, and the RBAC/PIM requests (`yes`/`no` plus the requestor email). Every other value lives in the GitHub Environment named by `input.json` → `environment`.

When `environment` is `dev`, every job runs in the GitHub Environment **`dev`**: it signs in with that environment's secrets and reads that environment's variables. To deploy to `qa`, `uat` or `prod`, create an environment with that name, add the same keys with that environment's values, and change `environment` in `input.json`.

Add everything below in **GitHub → Settings → Environments → `dev`**.

- **Values:** copied from the previous `input.json`.
- **Naming values** (`workload`, `system`, `purpose`) are **not** GitHub variables. They are set once in `input.json` → `target` and used by every module.
- **Data-structure variables (JSON):** enter them on a **single line**.

---

## 1. Secrets (`dev` → Environment secrets)

| Secret | Used by | Required when |
|---|---|---|
| `AZURE_CLIENT_ID` | `azure/login` (OIDC) in every job | Always |
| `AZURE_TENANT_ID` | `azure/login` (OIDC) in every job | Always |
| `AZURE_SUBSCRIPTION_ID` | `azure/login`; subscription check in the `context` job | Always |
| `VM_ADMIN_PASSWORD` | `modules/compute/vm.bicep` → `vmAdminPassword` | `vmWindows`, `vmLinux` or `vmWindowsSql` = yes |
| `SQL_ADMIN_PASSWORD` | `modules/database/sql.bicep` → `administratorLoginPassword` | `sqlDatabase` = yes |
| `POSTGRESQL_ADMIN_PASSWORD` | `modules/database/postgresql.bicep` → `administratorLoginPassword` | `postgresql` = yes |

---

## 2. Deployment target (in input.json) and tags

The modules build every resource name from naming tokens; see [resource-naming-standard.md](resource-naming-standard.md). Three of those values are set in **`input.json` → `target`**, not as GitHub variables:

| `input.json` key | Current value | Notes |
|---|---|---|
| `target.workload` | `platform-svc` | Must be `int-<system>-<entity>`, `app-<name>`, `platform-svc` or `shared-infra`. Gives the resource group name `rg-<workload>-<env>` and the `workload` tag. |
| `target.system` | `sap` | Source/target system, for example `sap`, `okta` or `fleet`. Used in VM names. |
| `target.purpose` | `app` | One purpose for the whole deployment, used in every resource name (see section 5). Must be 2-11 lowercase letters/digits: no spaces, no hyphens, no uppercase, because it is also part of the Key Vault and storage account names. |
| `target.location` | `eastus` | Azure region for every resource. |

`resourceTargets` holds only `yes`/`no` for each resource type.

The tags are a GitHub Environment variable:

| Variable | `dev` value | Notes |
|---|---|---|
| `RESOURCE_TAGS` | `{"owner":"<owner>","cost-center":"<cost-center>","data-class":"<data-class>","ManagedBy":"Bicep"}` | Must contain `owner`, `cost-center` and `data-class`; the run stops if any is missing. `env` and `workload` are added by the modules. `ManagedBy` comes from the previous tags. |

---

## 3. Variables per resource

### Resource Group — `resourceGroup`
Name: `rg-<target.workload>-dev`, so `rg-platform-svc-dev`. Only `RESOURCE_TAGS` from section 2 is needed.

### Network Security Group — `networkSecurityGroup`
Name: `nsg-pike-<target.purpose>-dev`

| Variable | `dev` value |
|---|---|
| `NSG_SECURITY_RULES` | `[]` |

### Route Table — `routeTable`
Name: `rt-pike-<target.purpose>-dev`

| Variable | `dev` value |
|---|---|
| `ROUTE_TABLE_ROUTES` | `[]` |
| `ROUTE_TABLE_DISABLE_BGP_PROPAGATION` | `false` |

### Virtual Network — `virtualNetwork`
Name: `vnet-pike-dev`

| Variable | `dev` value |
|---|---|
| `VNET_ADDRESS_PREFIXES` | `["10.40.0.0/16"]` |
| `VNET_DNS_SERVERS` | `[]` |

### Subnet — `subnet`
Name: `snet-<target.purpose>`. The subnet is associated with the NSG and route table only when those targets are `yes`.

| Variable | `dev` value |
|---|---|
| `SUBNET_ADDRESS_PREFIX` | `10.40.1.0/24` |
| `SUBNET_SERVICE_ENDPOINTS` | `[]` |
| `SUBNET_PRIVATE_ENDPOINT_NETWORK_POLICIES` | `Enabled` |
| `SUBNET_PRIVATE_LINK_SERVICE_NETWORK_POLICIES` | `Enabled` |

### Application Gateway Subnet — `applicationGatewaySubnet`
Name: `snet-<target.purpose>-agw` (the `-agw` suffix keeps it separate from the main subnet)

| Variable | `dev` value |
|---|---|
| `APP_GATEWAY_SUBNET_ADDRESS_PREFIX` | `10.40.2.0/24` |

### Load Balancer — `loadBalancer`
Name: `lb-pike-<target.purpose>-dev`. The frontend goes in subnet `snet-<target.purpose>`.

| Variable | `dev` value |
|---|---|
| `LOAD_BALANCER_SKU` | `Standard` |
| `LOAD_BALANCER_TIER` | `Regional` |
| `LOAD_BALANCER_FRONTENDS` | `[{"name":"frontend-private-001","privateIp":"10.40.1.10"}]` |
| `LOAD_BALANCER_BACKEND_POOLS` | `[{"name":"backend-pool-001","addresses":[]}]` |
| `LOAD_BALANCER_PROBES` | `[{"name":"probe-tcp-80","protocol":"Tcp","port":80,"intervalInSeconds":15,"numberOfProbes":2}]` |
| `LOAD_BALANCER_RULES` | `[{"name":"rule-tcp-80","frontendName":"frontend-private-001","backendPoolName":"backend-pool-001","probeName":"probe-tcp-80","protocol":"Tcp","frontendPort":80,"backendPort":80,"idleTimeoutInMinutes":4,"enableFloatingIp":false,"enableTcpReset":true}]` |

### Application Gateway — `applicationGateway`
Name: `agw-pike-dev`; public IP: `pip-agw-pike-dev`. The gateway goes in subnet `snet-<target.purpose>-agw`.

| Variable | `dev` value |
|---|---|
| `APP_GATEWAY_SKU` | `Standard_v2` *(this value was previously fixed inside the module)* |
| `APP_GATEWAY_PRIVATE_FRONTEND_IP` | `10.40.2.10` |
| `APP_GATEWAY_MIN_CAPACITY` | `2` |
| `APP_GATEWAY_MAX_CAPACITY` | `5` |
| `APP_GATEWAY_ENABLE_HTTP2` | `true` |
| `APP_GATEWAY_FRONTEND_PORTS` | `[{"name":"port-http-80","port":80}]` |
| `APP_GATEWAY_BACKEND_POOLS` | `[{"name":"backend-pool-001","backendAddresses":[]}]` |
| `APP_GATEWAY_HEALTH_PROBES` | `[{"name":"probe-http","protocol":"Http","host":"127.0.0.1","path":"/health","interval":30,"timeout":30,"unhealthyThreshold":3,"statusCodes":["200-399"]}]` |
| `APP_GATEWAY_BACKEND_HTTP_SETTINGS` | `[{"name":"http-settings-80","port":80,"protocol":"Http","requestTimeout":30,"cookieBasedAffinity":"Disabled","probeName":"probe-http"}]` |
| `APP_GATEWAY_LISTENERS` | `[{"name":"listener-public-http","frontendIPConfigurationName":"frontend-public","frontendPortName":"port-http-80","protocol":"Http"},{"name":"listener-private-http","frontendIPConfigurationName":"frontend-private","frontendPortName":"port-http-80","protocol":"Http"}]` |
| `APP_GATEWAY_ROUTING_RULES` | `[{"name":"rule-public-http","priority":100,"listenerName":"listener-public-http","backendPoolName":"backend-pool-001","httpSettingName":"http-settings-80"},{"name":"rule-private-http","priority":101,"listenerName":"listener-private-http","backendPoolName":"backend-pool-001","httpSettingName":"http-settings-80"}]` |

### Key Vault — `keyVault`
Name: `kv-pike-<target.purpose>-dev` (24 characters at most).

| Variable | `dev` value |
|---|---|
| `KEY_VAULT_SKU` | `standard` |
| `KEY_VAULT_SKU_FAMILY` | `A` |
| `KEY_VAULT_RBAC_AUTHORIZATION` | `true` |
| `KEY_VAULT_PURGE_PROTECTION` | `true` |
| `KEY_VAULT_SOFT_DELETE_RETENTION_DAYS` | `7` |
| `KEY_VAULT_PUBLIC_NETWORK_ACCESS` | `Enabled` |

### Storage Account — `storageAccount`
Name: `stpike<target.purpose>dev`. Storage account names have **no spaces, no hyphens, and are all lowercase**: this is why `target.purpose` must be lowercase letters or digits only.

| Variable | `dev` value |
|---|---|
| `STORAGE_ACCOUNT_SKU` | `Standard_LRS` |
| `STORAGE_ACCOUNT_KIND` | `StorageV2` |
| `STORAGE_ACCOUNT_ACCESS_TIER` | `Hot` |
| `STORAGE_ACCOUNT_MIN_TLS_VERSION` | `TLS1_2` |
| `STORAGE_ACCOUNT_HTTPS_ONLY` | `true` |
| `STORAGE_ACCOUNT_ALLOW_BLOB_PUBLIC_ACCESS` | `false` |
| `STORAGE_ACCOUNT_ALLOW_SHARED_KEY_ACCESS` | `true` |
| `STORAGE_ACCOUNT_PUBLIC_NETWORK_ACCESS` | `Enabled` |
| `STORAGE_ACCOUNT_CONTAINER_NAMES` | `["appdata"]` |
| `STORAGE_ACCOUNT_BLOB_SERVICE_NAME` | `default` |
| `STORAGE_ACCOUNT_CONTAINER_PUBLIC_ACCESS` | `None` |

### Azure SQL — `sqlDatabase`
Server name: `sql-<target.workload>-dev`; database name: `<target.purpose>`.

| Variable | `dev` value |
|---|---|
| `AZURE_SQL_ADMIN_USERNAME` | `pikehexsqladmin` |
| `AZURE_SQL_VERSION` | `12.0` |
| `AZURE_SQL_SKU` | `Basic` |
| `AZURE_SQL_TIER` | `Basic` |
| `AZURE_SQL_CAPACITY` | `5` |
| `AZURE_SQL_MAX_SIZE_GB` | `2` *(previously `databaseMaxSizeBytes: 2147483648`)* |
| `AZURE_SQL_PUBLIC_NETWORK_ACCESS` | `Disabled` |
| `AZURE_SQL_MIN_TLS_VERSION` | `1.2` |

### Azure OpenAI — `openAi`
Name and custom subdomain: `oai-pike-<target.purpose>-dev`

| Variable | `dev` value |
|---|---|
| `AZURE_OPENAI_SKU` | `S0` |
| `AZURE_OPENAI_PUBLIC_NETWORK_ACCESS` | `Enabled` |

### Virtual machines — `vmWindows`, `vmLinux`, `vmWindowsSql`
All three use `modules/compute/vm.bicep`. Name: `vm-pike-<target.system>-<target.purpose>-<win|lnx|sql>-dev`; NIC: `nic-<vm name>`. The VMs go in subnet `snet-<target.purpose>`. Image format: `publisher:offer:sku:version`.

Shared by all three VM types:

| Variable | `dev` value |
|---|---|
| `VM_ADMIN_USERNAME` | `azureadmin` |
| `VM_PRIVATE_IP_ALLOCATION_METHOD` | `Dynamic` |
| `VM_DISK_TYPE` | `StandardSSD_LRS` |
| `VM_OS_DISK_SIZE_GB` | `128` |
| `VM_BOOT_DIAGNOSTICS_ENABLED` | `true` |

Per VM type:

| Variable | `dev` value | Needed when |
|---|---|---|
| `VM_WINDOWS_SQL_IMAGE` | `MicrosoftSQLServer:SQL2022-WS2022:sqldev-gen2:latest` | `vmWindowsSql` = yes |
| `VM_WINDOWS_SQL_SIZE` | `Standard_D2as_v5` | `vmWindowsSql` = yes |
| `VM_WINDOWS_IMAGE` | Not in the previous input.json — owner to provide | `vmWindows` = yes |
| `VM_WINDOWS_SIZE` | Not in the previous input.json — owner to provide | `vmWindows` = yes |
| `VM_LINUX_IMAGE` | Not in the previous input.json — owner to provide | `vmLinux` = yes |
| `VM_LINUX_SIZE` | Not in the previous input.json — owner to provide | `vmLinux` = yes |

Every resource now gets the same tags (`RESOURCE_TAGS` plus `env` and `workload`).

### PostgreSQL Flexible Server — `postgresql`
Server name: `psql-pike-<target.purpose>-dev`. The module also creates its own delegated subnet `snet-<target.purpose>-psql` and the private DNS link `link-vnet-pike-dev`.

| Variable | `dev` value |
|---|---|
| `POSTGRESQL_ADMIN_USERNAME` | `pikehexpgadmin` |
| `POSTGRESQL_VERSION` | `15` |
| `POSTGRESQL_SKU` | `Standard_D2ads_v5` |
| `POSTGRESQL_TIER` | `GeneralPurpose` |
| `POSTGRESQL_STORAGE_SIZE_GB` | `32` |
| `POSTGRESQL_BACKUP_RETENTION_DAYS` | `7` |
| `POSTGRESQL_GEO_REDUNDANT_BACKUP` | `Disabled` *(previously fixed inside the module)* |
| `POSTGRESQL_HA_MODE` | `Disabled` *(previously fixed inside the module)* |
| `POSTGRESQL_SUBNET_ADDRESS_PREFIX` | `10.40.3.0/28` |
| `POSTGRESQL_PRIVATE_DNS_ZONE_NAME` | `privatelink.postgres.database.azure.com` |

---

## 4. Access requests

### RBAC — `accessRequests.rbac` (`yes` in the current input)

The requestor is always a Microsoft Entra **user**. The person receiving access is the **requestor email** in `input.json` → `accessRequests.rbac.requestorEmail` (currently `SKumarMunis-Hex-adm@pike.com`). The workflow looks up that email in Microsoft Entra ID, so the workflow's Azure identity needs Microsoft Graph read permission.

| Variable | `dev` value | Notes |
|---|---|---|
| `RBAC_SCOPE` | `resourceGroup` | `subscription`, `resourceGroup` or `storageAccount` |
| `RBAC_READER_ROLE_DEFINITION_ID` | `acdd72a7-3385-48ef-bd42-f606fba81ae7` | Built-in Reader role |
| `RBAC_STORAGE_ACCOUNT_NAME` | — | Only when `RBAC_SCOPE` = `storageAccount` |

The role is assigned on the resource group from section 3 (`rg-<target.workload>-dev`).

### PIM — `accessRequests.pim` (`no` in the current input)

The requestor is always a Microsoft Entra **user**. The person receiving the eligible role is the **requestor email** in `input.json` → `accessRequests.pim.requestorEmail`. Set it when `request` is `yes`.

| Variable | `dev` value | Notes |
|---|---|---|
| `PIM_READER_ROLE_DEFINITION_ID` | `acdd72a7-3385-48ef-bd42-f606fba81ae7` *(proposed: Reader)* | |
| `PIM_REQUEST_TYPE` | Owner to provide | `AdminAssign`, `AdminUpdate`, `AdminRemove`, `AdminExtend` or `AdminRenew` |
| `PIM_MAX_DURATION` | Owner to provide | ISO 8601 duration, for example `P90D` (the allowed list is in `pim.bicep`) |
| `PIM_JUSTIFICATION` | Owner to provide | Required |

PIM requests are submitted at subscription scope with `modules/access/pim/pim.bicep`.

---

## 5. Resulting `dev` names (from the current input.json)

| Resource | Name |
|---|---|
| Resource group | `rg-platform-svc-dev` |
| NSG | `nsg-pike-app-dev` |
| Route table | `rt-pike-app-dev` |
| VNet | `vnet-pike-dev` |
| Subnets | `snet-app` (main), `snet-app-agw` (application gateway), `snet-app-psql` (PostgreSQL, created by the PostgreSQL module) |
| Load balancer | `lb-pike-app-dev` |
| Application gateway | `agw-pike-dev` (public IP `pip-agw-pike-dev`) |
| Key Vault | `kv-pike-app-dev` |
| Storage account | `stpikeappdev` |
| SQL server / database | `sql-platform-svc-dev` / `app` |
| Azure OpenAI | `oai-pike-app-dev` |
| VM (Windows + SQL) | `vm-pike-sap-app-sql-dev` (computer name `sapappsqldev`) |
| PostgreSQL | `psql-pike-app-dev` |
