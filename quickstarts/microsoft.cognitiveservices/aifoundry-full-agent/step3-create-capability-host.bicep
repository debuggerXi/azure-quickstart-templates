param accountName string
param projectName string
param searchConnectionName string
param storageConnectionName string
param cosmosdbConnectionName string

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  name: projectName
  parent: account
}

resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview' = {
  name: '${accountName}-accountCapHost'
  parent: account
  properties: {
    capabilityHostKind: 'Agents'
    }
}

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  name: '${projectName}-projectCapHost'
  parent: project
  properties: {
    capabilityHostKind: 'Agents'
    vectorStoreConnections: [searchConnectionName]
    storageConnections: [storageConnectionName]
    threadStorageConnections : [cosmosdbConnectionName]
    }
}

/*
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