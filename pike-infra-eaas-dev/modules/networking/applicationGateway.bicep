param applicationGatewayName string
param location string
param vnetName string
param subnetName string
param publicIpName string
param privateFrontendIp string
@minValue(0)
@maxValue(125)
param minCapacity int = 1
@minValue(1)
@maxValue(125)
param maxCapacity int = 2
param frontendPorts array
param backendPools array
param backendHttpSettings array
param healthProbes array
param listeners array
param routingRules array
param enableHttp2 bool = true
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = { name: vnetName }
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: subnetName
}
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static', publicIPAddressVersion: 'IPv4' }
}
resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: applicationGatewayName
  location: location
  tags: tags
  properties: {
    sku: { name: 'Standard_v2', tier: 'Standard_v2' }
    autoscaleConfiguration: { minCapacity: minCapacity, maxCapacity: maxCapacity }
    enableHttp2: enableHttp2
    gatewayIPConfigurations: [{
      name: 'gateway-ip-config'
      properties: { subnet: { id: subnet.id } }
    }]
    frontendIPConfigurations: [
      { name: 'frontend-public', properties: { publicIPAddress: { id: publicIp.id } } }
      { name: 'frontend-private', properties: { privateIPAddress: privateFrontendIp, privateIPAllocationMethod: 'Static', subnet: { id: subnet.id } } }
    ]
    frontendPorts: [for port in frontendPorts: { name: port.name, properties: { port: port.port } }]
    backendAddressPools: [for pool in backendPools: { name: pool.name, properties: { backendAddresses: pool.backendAddresses } }]
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
output applicationGatewayId string = appGateway.id
output publicIpAddress string = publicIp.properties.ipAddress
