@description('Azure region, e.g. eastus or westeurope')
param location string = resourceGroup().location

@description('Short prefix for the web app. Will be combined with a GUID-like suffix.')
@minLength(3)
@maxLength(20)
param appBaseName string = 'pyapp'

@description('Short prefix for the ACR. Will be combined with a unique suffix.')
@minLength(3)
@maxLength(15)
param acrBaseName string = 'acr'

@description('Number of workers in the plan')
@minValue(1)
param planCapacity int = 1

// Unique-ish names (stable within RG)
var appSuffix = toLower(substring(guid(resourceGroup().id, appBaseName), 0, 8))
var webAppName = toLower('${appBaseName}-${appSuffix}')
var planName = '${appBaseName}-plan'
var acrName = toLower('${acrBaseName}${uniqueString(resourceGroup().id, acrBaseName)}')

// App Service Plan (Linux) – Premium v4 P3mV4
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  kind: 'linux'
  sku: {
    name: 'P3mV4'
    tier: 'PremiumV4'
    size: 'P3mV4'
    capacity: planCapacity
  }
  properties: {
    reserved: true
  }
}

// Web App (Linux) with System-assigned identity; module will set linuxFxVersion
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      // do NOT set linuxFxVersion here
    }
  }
  tags: {
    'azd-service-name': 'web'
  }
}

// ACR (Standard)
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: { name: 'Standard' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// Give Web App MSI AcrPull on the ACR
var acrPullRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

// "name" must be start-time computable
resource acrPullRA 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, webApp.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Configure runtime AFTER creation
module appConfig './core/host/appservice.bicep' = {
  name: 'configure-${webAppName}'
  params: {
    name: webApp.name
    location: location
    serverFarmId: plan.id
    linuxFxVersion: 'PYTHON|3.13'
    alwaysOn: true
    httpsOnly: true
    scmDoBuildDuringDeployment: true
    tags: {
      'azd-service-name': 'web'
    }
  }
}

output AZURE_LOCATION string = location
output AZURE_WEBAPP_NAME string = webApp.name
output AZURE_APPSERVICE_PLAN string = plan.name
output AZURE_CONTAINER_REGISTRY string = acr.name
output AZURE_CONTAINER_REGISTRY_LOGIN_SERVER string = acr.properties.loginServer
