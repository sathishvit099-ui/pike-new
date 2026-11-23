// Pike naming: agw-pike-<env>      e.g. agw-pike-dev   (public IP: pip-agw-pike-<env>)
// Gateway subnet: snet-<purpose>-agw inside vnet-pike-<env>

@description('Environment token.')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environmentName string

@description('Workload token (used for the workload tag).')
@minLength(3)
@maxLength(60)
param workload string

@description('Deployment purpose token (input.json target.purpose); locates snet-<purpose>-agw.')
@minLength(2)
@maxLength(11)
param purpose string

@description('Azure region.')
param location string

@description('Application gateway SKU (name and tier use the same value).')
@allowed(['Standard_v2', 'WAF_v2'])
param skuName string

@description('Static private frontend IP inside the gateway subnet.')
param privateFrontendIp string

@minValue(0)
@maxValue(125)
param minCapacity int

@minValue(2)
@maxValue(125)
param maxCapacity int

@description('Frontend port objects: { name, port }.')
param frontendPorts array

@description('Backend pool objects: { name, backendAddresses }.')
param backendPools array

@description('Backend HTTP setting objects.')
param backendHttpSettings array

@description('Health probe objects.')
param healthProbes array

@description('Listener objects. frontendIPConfigurationName must be frontend-public or frontend-private.')
param listeners array

@description('Routing rule objects.')
param routingRules array

@description('Enable HTTP/2.')
param enableHttp2 bool

@description('Tags. Must contain owner, cost-center and data-class; env and workload are added here.')
param tags object

var applicationGatewayName = 'agw-pike-${environmentName}'
var publicIpName = 'pip-agw-pike-${environmentName}'
var vnetName = 'vnet-pike-${environmentName}'
var resourceTags = union(tags, { env: environmentName, workload: workload })

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: 'snet-${purpose}-agw'
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: resourceTags
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: applicationGatewayName
  location: location
  tags: resourceTags
  properties: {
    sku: { name: skuName, tier: skuName }
    autoscaleConfiguration: {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    }
    enableHttp2: enableHttp2
    gatewayIPConfigurations: [{
      name: 'gateway-ip-config'
      properties: { subnet: { id: subnet.id } }
    }]
    frontendIPConfigurations: [
      {
        name: 'frontend-public'
        properties: { publicIPAddress: { id: publicIp.id } }
      }
      {
        name: 'frontend-private'
        properties: {
          privateIPAddress: privateFrontendIp
          privateIPAllocationMethod: 'Static'
          subnet: { id: subnet.id }
        }
      }
    ]
    frontendPorts: [for port in frontendPorts: {
      name: port.name
      properties: { port: port.port }
    }]
    backendAddressPools: [for pool in backendPools: {
      name: pool.name
      properties: { backendAddresses: pool.backendAddresses }
    }]
    probes: [for probe in healthProbes: {
      name: probe.name
      properties: {
        protocol: probe.protocol
        host: probe.host
        path: probe.path
        interval: probe.interval
        timeout: probe.timeout
        unhealthyThreshold: probe.unhealthyThreshold
        match: { statusCodes: probe.statusCodes }
      }
    }]
    backendHttpSettingsCollection: [for setting in backendHttpSettings: {
      name: setting.name
      properties: {
        port: setting.port
        protocol: setting.protocol
        requestTimeout: setting.requestTimeout
        cookieBasedAffinity: setting.cookieBasedAffinity
        probe: { id: resourceId('Microsoft.Network/applicationGateways/probes', applicationGatewayName, setting.probeName) }
      }
    }]
    httpListeners: [for listener in listeners: {
      name: listener.name
      properties: {
        frontendIPConfiguration: { id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, listener.frontendIPConfigurationName) }
        frontendPort: { id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, listener.frontendPortName) }
        protocol: listener.protocol
      }
    }]
    requestRoutingRules: [for rule in routingRules: {
      name: rule.name
      properties: {
        priority: rule.priority
        ruleType: 'Basic'
        httpListener: { id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, rule.listenerName) }
        backendAddressPool: { id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, rule.backendPoolName) }
        backendHttpSettings: { id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, rule.httpSettingName) }
      }
    }]
  }
}

output deployedResourceId string = appGateway.id
output deployedResourceName string = appGateway.name
output publicIpAddress string = publicIp.properties.ipAddress
