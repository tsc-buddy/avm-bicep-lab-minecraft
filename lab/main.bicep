@description('ShortName is required for a unique storage account name. Only 5 characters.')
param shortName string = 'bad'
param vnetName string = 'mcjava-vnet'
param vnetAddressPrefixes array = [
  '10.0.0.0/16'
]
param time string = utcNow()
param subnetAzureFirewallName string = 'AzureFirewallSubnet'
param subnetWebName string = 'app'
param subnetStorageName string = 'storage'
param subnetAzureFirewallPrefix string = '10.0.0.0/24'
param subnetStoragePrefix string = '10.0.1.0/24'
param subnetWebPrefix string = '10.0.2.0/24'
param subnetAzureFirewallManagementPrefix string = '10.0.3.0/26'
param subnetAzureFirewallManagementName string = 'AzureFirewallManagementSubnet'
param pdnsName string = 'privatelink.file.${environment().suffixes.storage}'
param workspaceName string = 'mcjava-law'
param storageAccountName string = 'mcjavastg${shortName}'
param blobName string = 'mcjavablob'
param location string = resourceGroup().location
param mngEnvName string = 'mcjava-cenv'
param cappsName string = 'mcjava-capps01'


/*
//\\//\\ Networking Components //\\//\\
This section creates the virtual network, private DNS zone, public IP address, route tables, Azure Firewall & policies.
*/

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
        defaultOutboundAccess: false
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        name: subnetWebName
        addressPrefix: subnetWebPrefix
        delegation: 'Microsoft.App/environments'
        defaultOutboundAccess: false
      }
      {
        name: subnetAzureFirewallManagementName
        addressPrefix: subnetAzureFirewallManagementPrefix
      }
    ]
  }
}

module routeTable 'br/public:avm/res/network/route-table:0.4.1' = {
  name: 'routeTableDeployment'
  params: {
    name: 'mcjava-rt'
    routes: [
      {
        name: 'to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: azfw.outputs.privateIp
          nextHopType: 'VirtualAppliance'
        }
      }
    ]
  }
}

module privateDNSZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
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

module fwpip 'br/public:avm/res/network/public-ip-address:0.7.1' = {
  name: '${time}-fwpipDeployment'
  params: {
    name: 'mcjava-fwpip'
    diagnosticSettings: []
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    roleAssignments: []
    skuName: 'Standard'
    skuTier: 'Regional'
  }
}

module azfw 'br/public:avm/res/network/azure-firewall:0.5.2' = {
  name: '${time}-azureFirewallDeployment'
  params: {
    name: 'mcjava-azfw'
    azureSkuTier: 'Standard'
    virtualNetworkResourceId: vnet.outputs.resourceId
    location: location
    threatIntelMode: 'Alert'
    firewallPolicyId: fwpip.outputs.resourceId
  }
}

module firewallPolicy 'br/public:avm/res/network/firewall-policy:0.2.0' = {
  name: 'firewallPolicyDeployment'
  params: {
    // Required parameters
    name: 'mcjava-afwp'
    // Non-required parameters
    allowSqlRedirect: true
    autoLearnPrivateRanges: 'Enabled'
    location: location

    ruleCollectionGroups: [
      {
        priority: 1000
        name: 'outbound'
        ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'vnet-outbound'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            fqdnTags: []
            webCategories: []
            targetFqdns: [
              '*'
            ]
            targetUrls: []
            terminateTLS: false
            sourceAddresses: [
              subnetWebPrefix
            ]
            destinationAddresses: []
            sourceIpGroups: []
            httpHeadersToInsert: []
          }
        ]
        name: 'vnet-outbound'
        priority: 300
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'nrc-containerapp-out'
            ipProtocols: [
              'TCP'
              'UDP'
            ]
            sourceAddresses: [
              subnetWebPrefix
            ]
            sourceIpGroups: []
            destinationAddresses: [
              'MicrosoftContainerRegistry'
              'AzureFrontDoorFirstParty'
              'AzureContainerRegistry'
              'AzureActiveDirectory'
              'AzureKeyVault'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '*'
            ]
          }
        ]
        name: 'container-app-outbound'
        priority: 400
      }
        ]
      }
      {
        priority: 1100
        name: 'minecraft-server'
        ruleCollections: [
          {
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            action: {
              type: 'Allow'
            }
            rules: [
              {
                ruleType: 'NetworkRule'
                name: 'nrc-minecraft-server-in'
                ipProtocols: [
                  'TCP'
                ]
                sourceAddresses: [
                  '0.0.0.0/0'
                ]
                sourceIpGroups: []
                destinationAddresses: [
                  managedEnvironment.outputs.staticIp
                ]
                destinationIpGroups: []
                destinationFqdns: []
                destinationPorts: [
                  '25565'
                ]
              }
            ]
            name: 'minecraft-server-in'
            priority: 200
          }
          {
            ruleCollectionType: 'FirewallPolicyNatRuleCollection'
            action: {
              type: 'Dnat'
            }
            rules: [
              {
                ruleType: 'NatRule'
                name: 'minecraft-server'
                translatedAddress: managedEnvironment.outputs.staticIp
                translatedPort: '25565'
                ipProtocols: [
                  'TCP'
                ]
                sourceAddresses: [
                  '*'
                ]
                sourceIpGroups: []
                destinationAddresses: [
                  fwpip.outputs.ipAddress
                ]
                destinationPorts: [
                  '25565'
                ]
              }
            ]
            name: 'nat-minecraft-server'
            priority: 100
          }
        ]
      }
    ]
    tier: 'Standard'
    defaultWorkspaceId: workspace.outputs.resourceId
    enableProxy: true
  }
}

// Associate the route table with the storage subnet
resource storageSubnetRTAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: '${vnetName}/${subnetStorageName}'
  properties: {
    addressPrefix: subnetStoragePrefix
    privateLinkServiceNetworkPolicies: 'Enabled'
    routeTable: {
      id: routeTable.outputs.resourceId
    }
  }
}

resource appSubnetRTAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: '${vnetName}/${subnetWebName}'
  properties: {
    addressPrefix: subnetWebPrefix
    routeTable: {
      id: routeTable.outputs.resourceId
    }
  }
}

/*
//\\//\\ Monitoring & Storage Components //\\//\\
This section creates the Log Analytics workspace and storage account.
*/

module workspace 'br/public:avm/res/operational-insights/workspace:0.9.1' = {
  name: '${time}-workspaceDeployment'
  params: {
    name: workspaceName
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
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privateDNSZone.outputs.resourceId
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

/*
//\\//\\ Compute Components//\\//\\
This section creates the managed environment, container app and public IP address.
*/

module pip 'br/public:avm/res/network/public-ip-address:0.7.1' = {
  name: '${time}-publicIpAddressDeployment'
  params: {
    // Required parameters
    name: 'mcjava-cenv-pip'
    // Non-required parameters
    diagnosticSettings: []
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
    storages: [
      {
        accessMode: 'ReadWrite'
        storageAccountName: storageAccount.outputs.name
        shareName: 'mcjavashare'
        kind: 'SMB'
      }
    ]
    platformReservedCidr: '172.17.17.0/24'
    platformReservedDnsIP: '172.17.17.17'
    workloadProfiles: [
      {
        maximumCount: 1
        minimumCount: 0
        name: 'CAW01'
        workloadProfileType: 'D4'
      }
    ]
  }
}

module minecraft 'br/public:avm/res/app/container-app:0.12.0' = {
  name: '${time}-${cappsName}'
  params: {
    name: cappsName
    containers: [
      {
        image: 'docker.io/itzg/minecraft-server'
        name: 'minecraft-server'
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
          { name: 'OPS', value: 'mattffffff' }
          { name: 'VERSION', value: '1.21.7'}
          { name: 'VIEW_DISTANCE', value: '16' }
        ]
      }
    ]
    volumes: [
      {
        name: 'mcjavashare'
        storageName: 'mcjavashare'
        storageType: 'AzureFile'
      }
    ]
    ingressTargetPort: 25565
    exposedPort: 25565
    ingressTransport: 'tcp'
    trafficWeight: 100
    trafficLatestRevision: true
    workloadProfileName: 'CAW01'
    environmentResourceId: managedEnvironment.outputs.resourceId
    scaleMaxReplicas: 1
    scaleMinReplicas: 1
  }
}
