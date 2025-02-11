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
param pdnsName string = 'privatelink.blob.core.windows.net'
param workspaceName string = 'oiwmin001'
param location string = resourceGroup().location
param storageAccountName string = 'mcjavaservfiles'
param blobName string = 'mcjavablob'
param utcNow string = utcNow(HHmm)

param mngEnvName string = 'mc0101'

param cappsName string = 'capmcjava01'

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

    diagnosticSettings: [
      {
        workspaceResourceId: workspace.outputs.resourceId
      }
    ]
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

module azfw 'br/public:avm/res/network/azure-firewall:0.5.2' = {
  name: '${time}-azureFirewallDeployment'
  params: {
    // Required parameters
    name: 'azfw001'
    azureSkuTier: 'Standard'
    virtualNetworkResourceId: vnet.outputs.resourceId
    location: location
    threatIntelMode: 'Alert'
    networkRuleCollections: [
      {
        name: 'allow-outbound'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 1000
          rules: [
            {
              name: 'allow-all'
              protocols: [
                'Any'
              ]
              destinationPorts: [
                '*'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '*'
              ]
            }
          ]
        }
      }
      {
        name: 'allow-in-minecraft'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 1001
          rules: [
            {
              name: 'allow-in-minecraft'
              protocols: [
                'Any'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '192.168.1.96/27'
              ]
              destinationPorts: [
                '25565'
              ]
            }
          ]
        }
      }
    ]
  }
}
