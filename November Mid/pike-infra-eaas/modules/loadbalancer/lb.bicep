@description('Load Balancer name')
param loadBalancerName string

@description('Azure region')
param location string

@description('Load Balancer SKU name')
@allowed([
  'Standard'
])
param skuName string = 'Standard'

@description('Load Balancer SKU tier')
@allowed([
  'Regional'
])
param skuTier string = 'Regional'

@description('Resource tags')
param tags object = {}

@description('Existing Virtual Network name')
param vnetName string

@description('Existing subnet name for the private frontend')
param subnetName string

@description('Frontend IP configurations')
param frontends array

@description('Backend address pools. Backend NIC/IP associations can be added after pool creation.')
param backendPools array

@description('Health probes')
param probes array

@description('Load balancing rules')
param loadBalancingRules array

var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: loadBalancerName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    frontendIPConfigurations: [
      for frontend in frontends: {
        name: frontend.name
        properties: {
          privateIPAddress: frontend.privateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    backendAddressPools: [
      for backendPool in backendPools: {
        name: backendPool.name
        properties: {}
      }
    ]
    probes: [
      for probe in probes: {
        name: probe.name
        properties: {
          protocol: probe.protocol
          port: probe.port
          intervalInSeconds: probe.intervalInSeconds
          numberOfProbes: probe.numberOfProbes
        }
      }
    ]
    loadBalancingRules: [
      for rule in loadBalancingRules: {
        name: rule.name
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, rule.frontendName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, rule.backendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, rule.probeName)
          }
          protocol: rule.protocol
          frontendPort: rule.frontendPort
          backendPort: rule.backendPort
          idleTimeoutInMinutes: rule.idleTimeoutInMinutes
          enableFloatingIP: rule.enableFloatingIp
          enableTcpReset: rule.enableTcpReset
        }
      }
    ]
  }
}

output loadBalancerId string = loadBalancer.id
output loadBalancerName string = loadBalancer.name
