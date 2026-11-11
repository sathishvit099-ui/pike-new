# Pike VM + SQL separate input

This folder is a reference configuration for:
- One Windows Server VM
- One Ubuntu Linux VM using password authentication
- One Windows VM using a SQL Server Marketplace image

## Required GitHub Actions secrets

- `VM_ADMIN_PASSWORD`
- `LINUX_VM_ADMIN_PASSWORD`
- `SQL_VM_ADMIN_PASSWORD`

Passwords are deliberately not stored in this JSON.

## Before deployment

1. Replace the request and subscription placeholders.
2. Confirm the resource group, VNet, and subnet exist.
3. Verify the VM SKU is available in EastUS.
4. Verify the exact SQL Server Marketplace Publisher, Offer, SKU, and Version in Azure Portal.
5. Confirm SQL licensing. Developer edition is for development/test, not production. Validate whether PAYG is the correct SQL VM license setting.

## Implementation limitation

This is an input specification only. It is not yet wired into the existing workflow.

The current baseline Windows VM module does not automatically support Linux password authentication. The existing SQL module deploys Azure SQL Database (PaaS), not SQL Server on a VM. A separate implementation must add Linux VM configuration and SQL Server Marketplace VM deployment, including SQL IaaS Agent / Microsoft.SqlVirtualMachine registration.

Do not pass this file to the existing deployment workflow until those modules and parameter mappings are implemented.
