param storageAccountName string
param searchAccountName string
param cosmosdbName string
param accountName string
param projectName string

var role = {
  StorageBlobOwner: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  CosmosdbDataContributor: '/subscriptions/${subscription().subscriptionId}/resourceGroups/$(resourceGroup().resourceGroupName)/providers/Microsoft.DocumentDB/databaseAccounts/myaiservice042604db/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
  SearchContributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  CosmosdbContributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/5bd9cd88-fe45-4216-938b-f97437e15450'
}

// Get a reference to the storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' existing = {
  name: storageAccountName
}

resource searchService 'Microsoft.Search/searchServices@2025-02-01-preview' existing = {
  name: searchAccountName
}

resource cosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = {
  name: cosmosdbName
}

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  name: projectName
  parent: account
}

// Grant permissions to the storage account
resource storageAccountAppRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' =  {
  name: guid(storageAccount.id, role['StorageBlobOwner'], accountName, projectName)
  scope: storageAccount
  properties: {
    roleDefinitionId: role['StorageBlobOwner']
    principalId: project.identity.principalId
  }
}

// Grant permissions to the search account
resource searchAccountAppRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' =  {
  name: guid(searchService.id, role['SearchContributor'], accountName, projectName)
  scope: searchService
  properties: {
    roleDefinitionId: role['StorageBlobOwner']
    principalId: project.identity.principalId
  }
}

// Grant permissions to the cosmosdb account
resource cosmosdbAccountAppRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' =  {
  name: guid(cosmosDBAccount.id, role['CosmosdbContributor'], accountName, projectName)
  scope: cosmosDBAccount
  properties: {
    roleDefinitionId: role['CosmosdbContributor']
    principalId: project.identity.principalId
  }
}

// Grant dataplane permissions to the cosmosdb account
resource assignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  name: guid(cosmosDBAccount.id, role['CosmosdbDataContributor'], accountName, projectName)
  parent: cosmosDBAccount
  properties: {
    principalId: project.identity.principalId
    roleDefinitionId: role['CosmosdbDataContributor']
    scope: cosmosDBAccount.id
  }
}
