// Pike naming: lb-pike-<purpose>-<env>      e.g. lb-pike-app-dev
// Frontend subnet: snet-<purpose> inside vnet-pike-<env>

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Workload token (used for the workload tag).')
@minLength(3)
@maxLength(60)
param workload string

@description('Deployment purpose token (input.json target.purpose).')
@minLength(2)
@maxLength(11)
param purpose string

@description('Azure region.')
param location string

@description('Load balancer SKU name.')
@allowed(['Standard'])
param skuName string

@description('Load balancer SKU tier.')
@allowed(['Regional'])
param skuTier string

@description('Frontend objects: { name, privateIp }.')
param frontends array

@description('Backend pool objects: { name }.')
param backendPools array

@description('Probe objects: { name, protocol, port, intervalInSeconds, numberOfProbes }.')
param probes array

@description('Load-balancing rule objects.')
param loadBalancingRules array

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var loadBalancerName = 'lb-pike-${purpose}-${environmentName}'
var vnetName = 'vnet-pike-${environmentName}'
var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-${purpose}')

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: loadBalancerName
  location: location
  tags: union(tags, { env: environmentName, workload: workload })
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

output deployedResourceId string = loadBalancer.id
output deployedResourceName string = loadBalancer.name
