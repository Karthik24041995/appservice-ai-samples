@description('Existing web app name to configure')
param name string

@description('Location of the web app')
param location string

@description('Server farm (plan) resource ID')
param serverFarmId string

@description('Runtime stack, e.g., PYTHON|3.13 or DOCKER|<registry>/<repo>:tag')
param linuxFxVersion string

@description('Force Always On')
param alwaysOn bool = true

@description('Enforce HTTPS-only')
param httpsOnly bool = true

@description('Set SCM_DO_BUILD_DURING_DEPLOYMENT app setting')
param scmDoBuildDuringDeployment bool = false

@description('Optional tags to apply')
param tags object = {}

resource site 'Microsoft.Web/sites@2023-12-01' existing = {
  name: name
}

// Patch top-level site props (httpsOnly, tags, plan)
resource sitePatch 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    httpsOnly: httpsOnly
    serverFarmId: serverFarmId
  }
  dependsOn: [ site ]
}

// Update siteConfig including linuxFxVersion
resource siteConfig 'Microsoft.Web/sites/config@2023-12-01' = {
  name: '${name}/web'
  properties: {
    linuxFxVersion: linuxFxVersion
    alwaysOn: alwaysOn
  }
  dependsOn: [ sitePatch ]
}

// Optional: SCM_DO_BUILD_DURING_DEPLOYMENT
resource appsettings 'Microsoft.Web/sites/config@2023-12-01' = if (scmDoBuildDuringDeployment) {
  name: '${name}/appsettings'
  properties: {
    'SCM_DO_BUILD_DURING_DEPLOYMENT': 'true'
  }
  dependsOn: [ siteConfig ]
}

output configuredLinuxFxVersion string = siteConfig.properties.linuxFxVersion
