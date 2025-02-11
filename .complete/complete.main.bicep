@description('ShortName is required for a unique storage account name. Only 5 characters.')
param shortName string = 'mystr'
param vnetName string = 'vnet-mcjava-priv'
param time string = utcNow()
param subnetStorageName string = 'storage'
param subnetWebName string = 'web'
param pdnsName string = 'privatelink.blob.core.windows.net'
param workspaceName string = 'oiwmin001'
param location string = resourceGroup().location
param storageAccountName string = '${shortName}mcjavaservfiles'
param blobName string = 'mcjavablob'

param mngEnvName string = 'mc0101'

param cappsName string = 'capmcjava01'

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: workspaceName
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource subnetStorage 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: subnetStorageName
  parent: vnet
}

resource subnetWeb 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: subnetWebName
  parent: vnet
}

resource pdnssto 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: pdnsName
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.15.0' = {
  name: '${time}-storageAccountDeployment'
  params: {
    // Required parameters
    name: storageAccountName
    // Non-required parameters
    allowBlobPublicAccess: true
    blobServices: {
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 10
      containerDeleteRetentionPolicyEnabled: true
      containers: [
        {
          enableNfsV3AllSquash: true
          enableNfsV3RootSquash: true
          name: blobName
          publicAccess: 'None'
        }
      ]
      deleteRetentionPolicyDays: 9
      deleteRetentionPolicyEnabled: true
      diagnosticSettings: [
        {
          metricCategories: [
            {
              category: 'AllMetrics'
            }
          ]
          name: 'customSetting'

          workspaceResourceId: workspace.id
        }
      ]
      lastAccessTimeTrackingPolicyEnabled: true
    }
    diagnosticSettings: [
      {
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
        name: 'customSetting'

        workspaceResourceId: workspace.id
      }
    ]
    enableHierarchicalNamespace: true
    enableNfsV3: true
    enableSftp: true
    fileServices: {
      diagnosticSettings: [
        {
          metricCategories: [
            {
              category: 'AllMetrics'
            }
          ]
          name: 'customSetting'
          workspaceResourceId: workspace.id
        }
      ]
      shares: [
        {
          accessTier: 'Hot'
          name: 'mcjavashare'
          shareQuota: 5120
        }
      ]
    }
    largeFileSharesState: 'Enabled'
    localUsers: []
    location: location
    managedIdentities: {
      systemAssigned: true
    }
    managementPolicyRules: []
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: pdnssto.id
            }
          ]
        }
        service: 'blob'
        subnetResourceId: subnetStorage.id
        tags: {
          Environment: 'Non-Prod'
          'hidden-title': 'This is visible in the resource name'
          Role: 'DeploymentValidation'
        }
      }
    ]
    requireInfrastructureEncryption: true
    sasExpirationPeriod: '180.00:00:00'
    skuName: 'Standard_ZRS'
    tags: {
      Environment: 'Non-Prod'
      'hidden-title': 'This is visible in the resource name'
      Role: 'DeploymentValidation'
    }
  }
}

module managedEnvironment 'br/public:avm/res/app/managed-environment:0.8.1' = {
  name: '${time}-managedEnvironmentDeployment'
  params: {
    // Required parameters
    logAnalyticsWorkspaceResourceId: workspace.id
    name: mngEnvName
    // Non-required parameters
    dockerBridgeCidr: '172.16.0.1/28'
    infrastructureResourceGroupName: 'mngmctest01'
    infrastructureSubnetId: subnetWeb.id
    internal: true
    location: location
    storages: [
      {
        storageAccountName: storageAccount.outputs.name
        shareName: 'mcjavashare'
        accessMode: 'ReadWrite'
        kind: 'SMB'
      }
    ]
    platformReservedCidr: '172.17.17.0/24'
    platformReservedDnsIP: '172.17.17.17'
    workloadProfiles: [
      {
        maximumCount: 3
        minimumCount: 0
        name: 'CAW01'
        workloadProfileType: 'D4'
      }
    ]
  }
}

module capps 'br/public:avm/res/app/container-app:0.12.0' = {
  name: '${time}-${cappsName}'
  params: {
    name: cappsName
    containers: [
      {
        image: 'docker.io/itzg/minecraft-server'
        name: 'minecraft'
        resources: {
          cpu: json('2')
          memory: '4Gi'
        }
        volumeMounts: [
          {
            volumeName: 'mcjavashare'
            mountPath: '/data'
          }
        ]
        env: [
          { name: 'EULA', value: 'true' }
          { name: 'MEMORY', value: '3G' }
          { name: 'DIFFICULTY', value: 'normal' }
          { name: 'SERVER_NAME', value: 'Minecraft' }
          { name: 'OPS', value: 'mattffffff' }
          { name: 'VIEW_DISTANCE', value: '32' }
          { name: 'ONLINE_MODE', value: 'true' }
        ]
      }
    ]
    volumes: [
      {
        name: 'mcjavashare'
        storageAccountName: storageAccount.outputs.name
        shareName: 'mcjavashare'
      }
    ]
    ingressTargetPort: 25565
    workloadProfileName: 'CAW01'
    environmentResourceId: managedEnvironment.outputs.resourceId
  }
}
// Container Insights
