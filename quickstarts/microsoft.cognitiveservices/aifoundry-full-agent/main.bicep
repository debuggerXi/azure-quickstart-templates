/*
  Azure AI Foundry standard account, project, dependent resources, connections and capability Hosts
  
  Description: 
  - Create an Azure AI Foundry account and project with standard setup
  - Create dependent resources required for full agent scenario suite
  - Create connector to attach dependent resources to AI Foundry account and project
  - Create agent capability host settings
  - [TODO] Account networking setting injection

*/

@description('Name of foundry account. It has to be unique. Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param foundryAccountName string

@description('Location for all resources.')
param location string = 'westus2'

@description('Name of the project')
param defaultProjectName string = '${foundryAccountName}proj'
param defaultProjectDisplayName string = 'Project'
param defaultProjectDescription string = 'Describe what your project is about.'

// Azure CosmosDB Account
@description('Name of the BYO CosmosDB Resource')
param cosmosDBAccountName string = '${foundryAccountName}db'
@description('Resource Group name of the BYO CosmosDB resource')
param cosmosDBAccountResourceGroupName string = resourceGroup().name
@description('Subscription ID of the BYO CosmosDB resource')
param cosmosDBAccountSubscriptionId string = subscription().subscriptionId

// Azure Storage Account
@description('Name of the BYO Storage Account')
param storageAccountName string = '${foundryAccountName}sa'
@description('Resource Group name of the BYO Azure Storage Account')
param azureStorageAccountResourceGroupName string = resourceGroup().name
@description('Subscription ID of the BYO Azure Storage Account')
param azureStorageAccountSubscriptionId string = subscription().subscriptionId

// Azure AI Search
@description('Name AI Search resource')
param aiSearchName string = '${foundryAccountName}search'
@description('Resource Group name of the AI Search resource')
param aiSearchServiceResourceGroupName string = resourceGroup().name
@description('Subscription ID of the AI Search resource')
param aiSearchServiceSubscriptionId string = subscription().subscriptionId

// User new or existing dependent resources
@allowed([
  'new'
  'existing'
])
param newOrExisting string = 'new'

/*
  Step 1: Create a Foundry Account 
*/
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: foundryAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryAccountName
    disableLocalAuth: false
  }
}

/*
  Step 2: Create a Foundry Project
*/

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  name: defaultProjectName
  parent: account
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: defaultProjectDisplayName
    description: defaultProjectDescription
    isDefault: true
  }
}

/*
  Step 3: Create dependent resources
*/
resource newSearchService 'Microsoft.Search/searchServices@2025-02-01-preview' = if (newOrExisting == 'new') {
  name: aiSearchName
  location: location
  sku: {
    name: 'basic'
  }
  properties: {}
}

resource existingSearchService 'Microsoft.Search/searchServices@2025-02-01-preview' existing = if (newOrExisting == 'existing') {
  name: aiSearchName
}

resource newCosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' = {
  name: cosmosDBAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {databaseAccountOfferType: 'Standard'}
}

resource existingCosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = if (newOrExisting == 'existing') {
  name: cosmosDBAccountName
}

resource newStorageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' = if (newOrExisting == 'new') {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {}
}

resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' existing = if (newOrExisting == 'existing') {
  name: storageAccountName
}

/*
  Step 4: Create Connections
*/
resource project_connection_cosmosdb 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  name: 'myThreadStorageProjectConnectionName'
  parent: project
  properties: {
    category: 'CosmosDB'
    target: ((newOrExisting == 'new') ? newCosmosDBAccount.properties.documentEndpoint : existingCosmosDBAccount.properties.documentEndpoint)
    authType: 'AAD'
    metadata: {
      ApiType: 'Azure'
      ResourceId: ((newOrExisting == 'new') ? newCosmosDBAccount.id : existingCosmosDBAccount.id)
      location: ((newOrExisting == 'new') ? newCosmosDBAccount.location : existingCosmosDBAccount.location)
    }
  }
}

resource project_connection_azure_storage 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  name: 'myStorageProjectConnectionName'
  parent: project
  properties: {
    category: 'AzureStorageAccount'
    target: ((newOrExisting == 'new') ? newStorageAccount.properties.primaryEndpoints.blob : existingStorageAccount.properties.primaryEndpoints.blob)
    authType: 'AAD'
    metadata: {
      ApiType: 'Azure'
      ResourceId: ((newOrExisting == 'new') ? newStorageAccount.id : existingStorageAccount.id)
      location: ((newOrExisting == 'new') ? newStorageAccount.location : existingStorageAccount.location)
    }
  }
}

resource project_connection_azureai_search 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  name: 'myVectorStoreProjectConnectionName'
  parent: project
  properties: {
    category: 'CognitiveSearch'
    target: ((newOrExisting == 'new') ? newSearchService.properties.endpoint : existingSearchService.properties.endpoint)
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: ((newOrExisting == 'new') ? newSearchService.id : existingSearchService.id)
      location: ((newOrExisting == 'new') ? newSearchService.location : existingSearchService.location)
    }
  }
}
/*
  Step 5: Project MI role assignment
*/

module roleAssignment './Module/Role-assignment.bicep' = {
  name: 'role-assignment'
  scope: resourceGroup()
  dependsOn: [
    project
  ]
  params:{
    storageAccountName: storageAccountName
	searchAccountName: aiSearchName
	cosmosdbName: cosmosDBAccountName
	projectName: defaultProjectName
    principalId: project.identity.principalId
  }
}

/*
  Step 6: Create Account and Project Capability Host
*/
resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview' = {
  name: '${foundryAccountName}-accountCapHost'
  parent: account
  properties: {
    capabilityHostKind: 'Agents'
    }
}

/*
resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  name: '${foundryAccountName}-projectCapHost'
  parent: project
  properties: {
    capabilityHostKind: 'Agents'
    vectorStoreConnections: [project_connection_azureai_search.name]
    storageConnections: [project_connection_azure_storage.name]
    threadStorageConnections : [project_connection_cosmosdb.name]
    }
}


  Optional Step: Deploy gpt-4o model
  - Subscription may not enable or have sufficient quota for gpt-4o model. Please adjust model accordingly to execute
  - Agents will use the build-in model deployments

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01'= {
  parent: account
  name: 'gpt-4o'
  sku : {
    capacity: 1
    name: 'GlobalStandard'
  }
  properties: {
    model:{
      name: 'gpt-4o'
      format: 'OpenAI'
      version: '2024-08-06'
    }
  }
}
*/

output accountId string = account.id
output accountName string = account.name