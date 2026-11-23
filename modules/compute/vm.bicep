// One module for the three VM types requested in input.json (CLAUDE.md patterns; VMs are not
// on the Pike naming sheet):
//   vmType = windows      -> vm-pike-<system>-<purpose>-win-<env>
//   vmType = linux        -> vm-pike-<system>-<purpose>-lnx-<env>
//   vmType = windows-sql  -> vm-pike-<system>-<purpose>-sql-<env>
// NIC: nic-<vm name>. Windows computer name (max 15): first 15 chars of <system><purpose><os><env>.
// Subnet: snet-<purpose> inside vnet-pike-<env>.

@description('VM type.')
@allowed(['windows', 'linux', 'windows-sql'])
param vmType string

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('System token: source/target system, lowercase (for example sap, okta, fleet).')
@minLength(2)
@maxLength(20)
param systemName string

@description('Deployment purpose token (input.json target.purpose).')
@minLength(2)
@maxLength(11)
param purpose string

@description('Workload token (used for the workload tag).')
@minLength(3)
@maxLength(60)
param workload string

@description('Azure region.')
param location string

@description('Marketplace image reference as publisher:offer:sku:version.')
param imageReference string

@description('VM size.')
param vmSize string

@description('Local administrator username.')
param adminUsername string

@secure()
@description('Local administrator password.')
param vmAdminPassword string

@description('Private IP allocation method.')
@allowed([
  'Dynamic'
  'Static'
])
param privateIpAllocationMethod string

@description('Managed OS disk storage account type.')
param osDiskStorageAccountType string

@description('OS disk size in GB; 0 uses the image default.')
param osDiskSizeGB int

@description('Enable boot diagnostics.')
param enableBootDiagnostics bool

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var osToken = vmType == 'linux' ? 'lnx' : (vmType == 'windows-sql' ? 'sql' : 'win')
var vmName = 'vm-pike-${systemName}-${purpose}-${osToken}-${environmentName}'
var computerName = vmType == 'linux' ? vmName : take('${systemName}${purpose}${osToken}${environmentName}', 15)
var nicName = 'nic-${vmName}'
var vnetName = 'vnet-pike-${environmentName}'
var image = split(imageReference, ':')
var resourceTags = union(tags, { env: environmentName, workload: workload })

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: 'snet-${purpose}'
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  tags: resourceTags
  properties: {
    ipConfigurations: [
      {
        name: '${nicName}-ipconfig'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: privateIpAllocationMethod
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  tags: resourceTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: vmAdminPassword
      linuxConfiguration: vmType == 'linux' ? {
        disablePasswordAuthentication: false
      } : null
    }
    storageProfile: {
      imageReference: {
        publisher: image[0]
        offer: image[1]
        sku: image[2]
        version: image[3]
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskStorageAccountType
        }
        diskSizeGB: osDiskSizeGB > 0 ? osDiskSizeGB : null
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: enableBootDiagnostics
      }
    }
  }
}

output deployedResourceId string = vm.id
output deployedResourceName string = vm.name
output computerName string = computerName
output networkInterfaceId string = nic.id
