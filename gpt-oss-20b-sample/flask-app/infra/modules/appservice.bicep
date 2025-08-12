@description('Existing web app name to configure')
param name string

@description('Location of the web app')
param location string

@description('Server farm (plan) resource ID')
param serverFarmId string

@description('Runtime stack, e.g., PYTHON|3.13 or DOCKER|...')
param linuxFxVersion string

@description('Force Always On')
param alwaysOn bool = true

@description('FTPS state: AllAllowed, FtpsOnly, or Disabled')
param ftpsState string = 'FtpsOnly'

@description('Minimum TLS version: 1.2 or 1.3 (where supported)')
param minTlsVersion string = '1.2'

@description('Enforce HTTPS-only')
param httpsOnly bool = true

@description('Set SCM_DO_BUILD_DURING_DEPLOYMENT app setting')
param scmDoBuildDuringDeployment bool = true

@description('Optional tags to apply to the Web App')
param tags object = {}

resource site 'Microsoft.Web/sites@2023-12-01' existing = {
  name: name
}

// Patch top-level site props (e.g., httpsOnly, tags, plan linkage)
resource sitePatch 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    httpsOnly: httpsOnly
    serverFarmId: serverFarmId
  }
  dependsOn: [
    site
  ]
}

// Update the "web" config (siteConfig) including linuxFxVersion
resource siteConfig 'Microsoft.Web/sites/config@2023-12-01' = {
  name: '${name}/web'
  properties: {
    linuxFxVersion: linuxFxVersion
    alwaysOn: alwaysOn
    ftpsState: ftpsState
    minTlsVersion: minTlsVersion
  }
  dependsOn: [
    sitePatch
  ]
}

// App settings: inject SCM_DO_BUILD_DURING_DEPLOYMENT if requested
resource appsettings 'Microsoft.Web/sites/config@2023-12-01' = if (scmDoBuildDuringDeployment) {
  name: '${name}/appsettings'
  properties: {
    'SCM_DO_BUILD_DURING_DEPLOYMENT': 'true'
  }
  dependsOn: [
    siteConfig
  ]
}

output configuredLinuxFxVersion string = siteConfig.properties.linuxFxVersion
