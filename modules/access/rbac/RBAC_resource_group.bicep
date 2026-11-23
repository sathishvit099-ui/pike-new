targetScope = 'resourceGroup'

// @description('Name of the existing resource group receiving the role assignment.')
// param resourceGroupName string

@description('Microsoft Entra object ID of the existing principal.')
param principalId string

@description('Built-in or custom role definition GUID.')
param roleDefinitionGuid string

@description('Principal type.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param principalType string = 'User'

// resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
//   name: resourceGroupName
// }

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)
var assignmentName = guid(resourceGroup().id, principalId, roleDefinitionId)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: assignmentName
  // scope: targetResourceGroup
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: principalType
  }
}

output roleAssignmentId string = roleAssignment.id
output assignedResourceGroupId string = resourceGroup().id

output deployedResourceId string = roleAssignment.id
output deployedResourceName string = roleAssignment.name
