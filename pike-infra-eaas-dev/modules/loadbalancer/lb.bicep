@description('Load Balancer name')
param loadBalancerName string
@description('Azure region')
param location string
@allowed(['Standard'])
param skuName string = 'Standard'
@allowed(['Regional'])
param skuTier string = 'Regional'
param tags object = {}
param vnetName string
param subnetName string
param frontends array
param backendPools array
param probes array
param loadBalancingRules array

var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: loadBalancerName
  location: location
  tags: tags
  sku: { name: skuName, tier: skuTier }
  properties: {
    frontendIPConfigurations: [for frontend in frontends: {
      name: frontend.name
      properties: {
        privateIPAddress: frontend.privateIp
        privateIPAllocationMethod: 'Static'
        subnet: { id: subnetId }
      }
    }]
    backendAddressPools: [for pool in backendPools: { name: pool.name }]
    probes: [for probe in probes: {
      name: probe.name
      properties: {
        protocol: probe.protocol
        port: probe.port
        intervalInSeconds: probe.intervalInSeconds
        numberOfProbes: probe.numberOfProbes
      }
    }]
    loadBalancingRules: [for rule in loadBalancingRules: {
      name: rule.name
      properties: {
        frontendIPConfiguration: { id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, rule.frontendName) }
        backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, rule.backendPoolName) }
        probe: { id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, rule.probeName) }
        protocol: rule.protocol
        frontendPort: rule.frontendPort
        backendPort: rule.backendPort
        idleTimeoutInMinutes: rule.idleTimeoutInMinutes
        enableFloatingIP: rule.enableFloatingIp
        enableTcpReset: rule.enableTcpReset
      }
    }]
  }
}
output loadBalancerId string = loadBalancer.id
