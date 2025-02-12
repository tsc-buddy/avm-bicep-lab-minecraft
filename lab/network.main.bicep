@description('ShortName is required for a unique storage account name. Only 5 characters.')
param shortName string = ''
param vnetName string = 'vnet-mcjava-priv'
param vnetAddressPrefixes array = [
  '192.168.1.0/24'
]
param time string = utcNow()
param subnetAzureFirewallName string = 'AzureFirewallSubnet'
param subnetAzureFirewallPrefix string = '192.168.1.0/26'
param subnetStorageName string = 'storage'
param subnetStoragePrefix string = '192.168.1.64/27'
param subnetWebName string = 'web'
param subnetWebPrefix string = '192.168.1.96/27'
param subnetAzureFirewallManagementName string = 'AzureFirewallManagementSubnet'
param subnetAzureFirewallManagementPrefix string = '192.168.1.128/26'
param pdnsName string = 'privatelink.file.core.windows.net'
param workspaceName string = 'oiwmin001'
param storageAccountName string = '${shortName}mcjavaservfiles'
param blobName string = 'mcjavablob'
param location string = resourceGroup().location

param mngEnvName string = 'mc0101'

module vnet 'br/public:avm/res/network/virtual-network:0.5.2' = {
  name: '${time}-privateVnet'
  params: {
    name: vnetName
    addressPrefixes: vnetAddressPrefixes
    subnets: [
      {
        name: subnetAzureFirewallName
        addressPrefix: subnetAzureFirewallPrefix
      }
      {
        name: subnetStorageName
        addressPrefix: subnetStoragePrefix
      }
      {
        name: subnetWebName
        addressPrefix: subnetWebPrefix
        delegation: 'Microsoft.App/environments'
      }
      {
        name: subnetAzureFirewallManagementName
        addressPrefix: subnetAzureFirewallManagementPrefix
      }
    ]
  }
}

module pdnssto 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: '${time}-storagedns'
  params: {
    name: pdnsName
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: vnet.outputs.resourceId
      }
    ]
  }
}

module pip 'br/public:avm/res/network/public-ip-address:0.7.1' = {
  name: '${time}-publicIpAddressDeployment'
  params: {
    // Required parameters
    name: 'npiawaf001'
    // Non-required parameters

    diagnosticSettings: []
    lock: {
      kind: 'CanNotDelete'
      name: 'myCustomLockName'
    }
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    roleAssignments: []
    skuName: 'Standard'
    skuTier: 'Regional'
    tags: {
      Environment: 'Non-Prod'
      'hidden-title': 'This is visible in the resource name'
      Role: 'DeploymentValidation'
    }
  }
}

module firewallPolicy 'br/public:avm/res/network/firewall-policy:0.2.0' = {
  name: 'firewallPolicyDeployment'
  params: {
    // Required parameters
    name: 'afwp01'
    // Non-required parameters
    allowSqlRedirect: true
    autoLearnPrivateRanges: 'Enabled'
    location: location
    ruleCollectionGroups: [
      {
        name: 'inbound'
        priority: 5000
        ruleCollections: [
          {
            action: {
              type: 'Allow'
            }
            name: 'collection'
            priority: 5555
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            rules: [
              {
                destinationAddresses: []
                destinationFqdns: [
                  '*'
                ]
                destinationIpGroups: []
                destinationPorts: [
                  '80'
                  '443'
                ]
                ipProtocols: [
                  'TCP'
                ]
                name: 'rule001'
                ruleType: 'ApplicationRule'
                sourceAddresses: [
                  vnetAddressPrefixes[0]
                ]
                sourceIpGroups: []
              }
              {
                destinationAddresses: [
                  '*'
                ]
                destinationFqdns: []
                destinationIpGroups: []
                destinationPorts: [
                  '*'
                ]
                ipProtocols: [
                  'TCP'
                  'UDP'
                ]
                name: 'rule002'
                ruleType: 'NetworkRule'
                sourceAddresses: [
                  vnetAddressPrefixes[0]
                ]
                sourceIpGroups: []
              }
            ]
          }
          {
            action: {
              type: 'Allow'
            }
            name: 'collection'
            priority: 5555
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            rules: [
              {
                destinationAddresses: [
                  managedEnvironment.outputs.staticIp
                ]
                destinationFqdns: []
                destinationIpGroups: []
                destinationPorts: [
                  '25565'
                ]
                ipProtocols: [
                  'TCP'
                ]
                name: 'rule001'
                ruleType: 'NetworkRule'
                sourceAddresses: [
                  '*'
                ]
                sourceIpGroups: []
              }
              {
                destinationAddresses: [
                  pip.outputs.ipAddress
                ]
                destinationPorts: [
                  '25565'
                ]
                ipProtocols: [
                  'TCP'
                ]
                ruleType: 'NatRule'
                sourceAddresses: [
                  '*'
                ]
                sourceIpGroups: []
                translatedAddress: managedEnvironment.outputs.staticIp
              }
            ]
          }
        ]
      }
    ]
    tags: {
      Environment: 'Non-Prod'
      'hidden-title': 'This is visible in the resource name'
      Role: 'DeploymentValidation'
    }
    tier: 'Premium'
  }
}

module azfw 'br/public:avm/res/network/azure-firewall:0.5.2' = {
  name: '${time}-azureFirewallDeployment'
  params: {
    // Required parameters
    name: 'azfw001'
    azureSkuTier: 'Standard'
    virtualNetworkResourceId: vnet.outputs.resourceId
    location: location
    threatIntelMode: 'Alert'
    firewallPolicyId: firewallPolicy.outputs.resourceId
  }
}

module workspace 'br/public:avm/res/operational-insights/workspace:0.9.1' = {
  name: '${time}-workspaceDeployment'
  params: {
    // Required parameters
    name: workspaceName
    // Non-required parameters
    location: location
  }
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.15.0' = {
  name: '${time}-storageAccountDeployment'
  params: {
    // Required parameters
    name: storageAccountName
    // Non-required parameters
    allowSharedKeyAccess: true
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

          workspaceResourceId: workspace.outputs.resourceId
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

        workspaceResourceId: workspace.outputs.resourceId
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
          workspaceResourceId: workspace.outputs.resourceId
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
              privateDnsZoneResourceId: pdnssto.outputs.resourceId
            }
          ]
        }
        service: 'file'
        subnetResourceId: vnet.outputs.subnetResourceIds[1]
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
    logAnalyticsWorkspaceResourceId: workspace.outputs.resourceId
    name: mngEnvName
    // Non-required parameters
    dockerBridgeCidr: '172.16.0.1/28'
    infrastructureResourceGroupName: 'mngmctest01'
    infrastructureSubnetId: vnet.outputs.subnetResourceIds[2]
    internal: true
    location: location
    storages: []
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

output PublicIpAddress string = pip.outputs.ipAddress
