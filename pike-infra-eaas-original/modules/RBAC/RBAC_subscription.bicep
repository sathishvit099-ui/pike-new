targetScope = 'subscription'

@description('Microsoft Entra object ID of the existing user, group, or service principal.')
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

@description('Optional assignment name seed. A deterministic GUID is generated when omitted.')
param assignmentSeed string = ''

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)
var assignmentName = empty(assignmentSeed)
  ? guid(subscription().id, principalId, roleDefinitionId)
  : guid(subscription().id, principalId, roleDefinitionId, assignmentSeed)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: assignmentName
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: principalType
  }
}

output roleAssignmentId string = roleAssignment.id
