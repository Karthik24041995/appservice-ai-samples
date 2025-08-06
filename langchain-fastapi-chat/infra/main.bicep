@description('Name prefix for resources')
param namePrefix string = 'fastapiapp'

@description('Location for all resources')
param location string = resourceGroup().location

@description('App Service SKU')
param sku string = 'P0V3'

@description('AI Foundry Model deployment name')
param aiFoundryModelName string = 'gpt-4o'

//
// Generate a globally unique suffix for names
//
var uniqueSuffix    = toLower(uniqueString(resourceGroup().id, location))
var appServiceName  = '${namePrefix}-web-${uniqueSuffix}'
var aiFoundryName   = '${namePrefix}-aifoundry-${uniqueSuffix}'
var aiFoundryProj   = '${namePrefix}-proj-${uniqueSuffix}'
var appServicePlanName = '${namePrefix}-plan'

//
// App Service Plan (Linux)
//
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: sku
    tier: 'PremiumV3'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

//
// Azure AI Foundry Account
//
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: aiFoundryName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    apiProperties: {}
    customSubDomainName: aiFoundryName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    allowProjectManagement: true
    defaultProject: aiFoundryProj
    associatedProjects: [
      aiFoundryProj
    ]
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

//
// Default Project for AI Foundry
//
resource aiFoundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  name: aiFoundryProj
  parent: aiFoundry
  location: location
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

//
// GPT-4o Foundry Deployment
//
resource aiFoundryDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  name: aiFoundryModelName
  parent: aiFoundry
  sku: {
    name: 'GlobalStandard'
    capacity: 100 // ✅ lower than quota
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 100
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

//
// Web App via appservice.bicep module
//
module web './core/host/appservice.bicep' = {
  name: 'web'
  params: {
    name: appServiceName
    location: location
    appServicePlanId: appServicePlan.id
    runtimeName: 'python'
    runtimeVersion: '3.13'
    scmDoBuildDuringDeployment: true
    startupCommand: 'python -m uvicorn app:app --host 0.0.0.0'
    tags: {
      'azd-service-name': 'web'
    }
  }
}

//
// Role Assignments (allow Web App to call AI Foundry via Managed Identity)
//
resource roleAssignmentCognitiveUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'foundry-user-role', appServiceName)
  scope: aiFoundry
  properties: {
    principalId: web.outputs.identityPrincipalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services User
    )
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentOpenAIUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'foundry-openai-user-role', appServiceName)
  scope: aiFoundry
  properties: {
    principalId: web.outputs.identityPrincipalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
    )
    principalType: 'ServicePrincipal'
  }
}

//
// Configure App Settings to use Foundry Endpoint and Deployment Name
//
resource appSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  name: '${appServiceName}/appsettings'
  properties: {
    ENDPOINT_URL: aiFoundry.properties.endpoint
    DEPLOYMENT_NAME: aiFoundryModelName
  }
  dependsOn: [
    web
    aiFoundry
    aiFoundryDeployment
  ]
}

//
// Outputs
//
output appServiceUrl string     = web.outputs.url
output aiFoundryEndpoint string = aiFoundry.properties.endpoint
