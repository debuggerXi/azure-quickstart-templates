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
  name: cosmosDBAccountName
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
  name: storageAccountName
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
  name: aiSearchName
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

output accountId string = account.id
output accountName string = account.name