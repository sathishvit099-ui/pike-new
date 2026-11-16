# PIKE Infrastructure as Code — Dev

This folder is the standalone project copied from the November 11 working ZIP, with Load Balancer and Application Gateway additions.

## Project structure

- `.github/workflows/deploy.yml` — one manually triggered Windows self-hosted GitHub Actions workflow
- `input.json` — one environment input file
- `modules/` — reusable Bicep modules for resource groups, networking, Load Balancer, Application Gateway, compute, database, storage, security and AI

## Before running

Configure GitHub Actions secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `VM_ADMIN_PASSWORD`, and `SQL_ADMIN_PASSWORD`. Configure Entra workload identity federation for the repository and `dev` environment.

The runner must be Windows self-hosted with labels `self-hosted`, `X64`, `Windows`, and Azure CLI installed at `C:\\Program Files\\Microsoft SDKs\\Azure\\CLI2\\wbin\\az.cmd`.

Review `input.json` carefully before deployment. The sample uses East US. The workflow performs What-If before each resource deployment. It has not been run against your customer subscription.

## Networking prerequisites

- Application Gateway uses dedicated subnet `snet-appgw-dev-001` (`10.40.2.0/24`). Do not place other resources in this subnet.
- Load Balancer and Application Gateway backend pools are initially empty. Attach the real backend NICs/IPs before expecting traffic to flow.
- The Application Gateway probe host `127.0.0.1` and path `/health` are placeholders. Replace them with the real backend host and health endpoint.
- Verify private frontend IPs are unused and inside the configured subnet CIDRs.
- Configure approved NSG rules; the sample NSG currently has an empty rule list.

Passwords are passed from GitHub secrets, not stored in `input.json`.
