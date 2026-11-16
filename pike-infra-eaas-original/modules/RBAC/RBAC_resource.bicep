targetScope = 'resourceGroup'

@description('Name of the existing Storage Account receiving the role assignment.')
param storageAccountName string

@description('Microsoft Entra object ID of the existing principal.')
param principalId string

@description('Built-in or custom role definition GUID.')
param roleDefinitionGuid string

@description('Principal type: User, Group, or ServicePrincipal.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param principalType string = 'User'

resource targetStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)
var assignmentName = guid(targetStorageAccount.id, principalId, roleDefinitionId)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: assignmentName
  scope: targetStorageAccount
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: principalType
  }
}

output roleAssignmentId string = roleAssignment.id
output assignedResourceId string = targetStorageAccount.id
