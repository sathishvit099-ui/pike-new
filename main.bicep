targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string

@description('Resource tags applied to supported resources.')
param tags object

@description('Virtual network configuration.')
param vnet object

@description('Subnet configuration.')
param subnet object
param nic object

@description('Linux virtual machine configuration.')
param vm object

module virtualNetwork './modules/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    location: location
    vnetName: vnet.name
    addressPrefix: vnet.addressPrefix
    tags: tags
  }
}

module applicationSubnet './modules/subnet.bicep' = {
  name: 'deploy-subnet'
  params: {
    vnetName: vnet.name
    subnetName: subnet.name
    addressPrefix: subnet.addressPrefix
  }
  dependsOn: [
    virtualNetwork
  ]
}

module networkInterface './modules/nic.bicep' = {
  name: 'deploy-nic'
  params: {
    location: location
    nicName: nic.name
    subnetId: applicationSubnet.outputs.subnetId
    tags: tags
  }
}

module virtualMachine './modules/vm-linux.bicep' = {
  name: 'deploy-linux-vm'
  params: {
    location: location
    vmName: vm.name
    vmSize: vm.size
    adminUsername: vm.adminUsername
    sshPublicKey: vm.sshPublicKey
    osDiskSizeGB: vm.osDiskSizeGB
    nicId: networkInterface.outputs.nicId
    tags: tags
  }
}

output virtualNetworkId string = virtualNetwork.outputs.vnetId
output subnetId string = applicationSubnet.outputs.subnetId
output networkInterfaceId string = networkInterface.outputs.nicId
output virtualMachineName string = virtualMachine.outputs.vmName
