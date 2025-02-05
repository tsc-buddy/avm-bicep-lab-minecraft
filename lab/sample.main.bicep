// Example Parameters:

// param vnetName string = 'vnet-mcjava-priv'
// param vnetAddressPrefixes array = [
//   '192.168.1.0/24'
// ]
// param subnetAzureFirewallName string = 'AzureFirewallSubnet'
// param subnetAzureFirewallPrefix string = '192.168.1.0/26'
// param subnetStorageName string = 'storage'
// param subnetStoragePrefix string = '192.168.1.64/27'
// param subnetWebName string = 'web'
// param subnetWebPrefix string = '192.168.1.96/27'
// param subnetAzureFirewallManagementName string = 'AzureFirewallManagementSubnet'
// param subnetAzureFirewallManagementPrefix string = '192.168.1.128/26'
// param pdnsName string = 'privatelink.blob.core.windows.net'
// param midName string = 'mid-mcjava'
// param midTags object = {
//   application: 'mcjava'
// }

// param workspaceName string = 'oiwmin001'
// param location string = location
// param storageAccountName string = 'mcjavaservfiles01'
// param blobName string = 'mcjavablob'


// param mngEnvName string = 'mc0101'

// param workloadProfiles array = [
//   {
//     maximumCount: 3
//     minimumCount: 0
//     name: 'CAW01'
//     workloadProfileType: 'D4'
//   }
// ]

// param cappsName string = 'capmcjava01'

// param cappsContainers array = [
//   {
//     image: 'docker.io/itzg/minecraft-server'
//     name: 'minecraft-container'
//     resources: {
//       cpu: '2'
//       memory: '4Gi'
//     }
//     env: [
//       { name: 'EULA', value: 'true' }
//       { name: 'MEMORY', value: '4G' }
//       { name: 'DIFFICULTY', value: 'normal' }
//       { name: 'SERVER_NAME', value: 'Minecraft' }
//       { name: 'OPS', value: 'LurkingMedal140' }
//       { name: 'VIEW_DISTANCE', value: '32' }
//     ]
//   }
// ]


module vnet 'br/public:avm/res/network/virtual-network:0.x.x' = {

}

module pdnssto 'br/public:avm/res/network/private-dns-zone:0.x.x' = {

}

module mid 'br/public:avm/res/managed-identity/user-assigned-identity:0.x.x' = {

}

module pip 'br/public:avm/res/network/public-ip-address:0.x.x' = {
  
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.x.x' = {
  
}

module workspace 'br/public:avm/res/operational-insights/workspace:0.x.x' = {

}

module managedEnvironment 'br/public:avm/res/app/managed-environment:0.x.x' = {
  
}

module capps 'br/public:avm/res/app/container-app:0.x.x' = {
  
}

// Container Insights
