

resource "azurerm_resource_group" "rg" {
  for_each = local.rg
  name     = each.key
  location = each.value
  tags     = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"]
    ]
  }
}

###############################################
# Logs & Diags
###############################################

resource "azurerm_storage_account" "log" {
  for_each = toset(["vmdiag","flowlog"])
  name                     = "${local.prefix}${each.value}"
  resource_group_name      = azurerm_resource_group.rg["rgCore"].name
  location                 = azurerm_resource_group.rg["rgCore"].location
  min_tls_version          = "TLS1_2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

resource "azurerm_log_analytics_workspace" "defaultLaw" {
  name                = "${local.prefix}GlobalLaw"
  resource_group_name = azurerm_resource_group.rg["rgCore"].name
  location            = azurerm_resource_group.rg["rgCore"].location
  sku                 = "PerGB2018"
  retention_in_days   = 365
  tags                = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

###############################################
# Automation Account
###############################################

resource "azurerm_automation_account" "automation" {
  name                = "${local.prefix}Automation"
  resource_group_name = azurerm_resource_group.rg["rgCore"].name
  location            = azurerm_resource_group.rg["rgCore"].location

  sku_name = "Basic"

  tags = merge(local.defaultTags, {})

  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

###############################################
# Keyvault
###############################################

resource "azurerm_key_vault" "kvCore" {
  name                        = substr("${local.prefix}KvCore",0,24)
  resource_group_name         = azurerm_resource_group.rg["rgSecrets"].name
  location                    = azurerm_resource_group.rg["rgSecrets"].location
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"
}

resource "azurerm_key_vault_access_policy" "kvPolicy" {
    key_vault_id = azurerm_key_vault.kvCore.id
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Backup", "Create", "Delete", "DeleteIssuers",
      "Get", "GetIssuers", "Import", "List", "ListIssuers",
      "ManageContacts", "ManageIssuers", "Purge", "Recover",
      "Restore", "SetIssuers", "Update"
    ]
    key_permissions = [
      "Backup", "Create", "Decrypt", "Delete",
      "Encrypt", "Get", "Import", "List",
      "Purge", "Recover", "Restore", "Sign",
      "UnwrapKey", "Update", "Verify", "WrapKey"
    ]

    secret_permissions = [
      "Backup", "Delete", "Get", "List",
      "Purge", "Recover", "Restore", "Set"
    ]

    storage_permissions = [
      "Backup", "Delete", "DeleteSAS", "Get",
      "GetSAS", "List", "ListSAS", "Purge",
      "Recover", "RegenerateKey", "Restore",
      "Set", "SetSAS", "Update"
    ]
}

###############################################
# Backup
###############################################

resource "azurerm_recovery_services_vault" "rsv" {
  name                = "rsv${title(local.prefix)}"
  sku                 = "Standard"
  location            = azurerm_resource_group.rg["rgBackup"].location
  resource_group_name = azurerm_resource_group.rg["rgBackup"].name
  tags                = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

resource "azurerm_backup_policy_vm" "backupPolicies" {
  for_each            = var.backupPolicies
  name                = "dailyBackup${each.key}"
  resource_group_name = azurerm_recovery_services_vault.rsv.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.rsv.name
  timezone            = "UTC"
  backup {
    frequency = "Daily"
    time      = "22:00"
  }
  retention_daily {
    count = each.value
  }
}

###############################################
# Virtual Network
###############################################

# VNets
resource "azurerm_virtual_network" "vnet" {
  for_each            = local.vnets
  name                = each.key
  address_space       = each.value.addressSpace
  dns_servers         = each.value.dnsServers
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name
  tags                = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
  depends_on = [
    azurerm_network_watcher.networkWatcher
  ]
}

resource "azurerm_network_watcher" "networkWatcher" {
  for_each = toset(distinct([ for k,v in azurerm_resource_group.rg : v.location ]))
  name                = "NetworkWatcher_${lower(each.value)}"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name
}

resource "azurerm_dns_zone" "dns" {
  name                = var.pubDomain
  resource_group_name = azurerm_resource_group.rg["rgCore"].name
  tags                = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_private_dns_zone" "dns" {
  #name                = var.domain
  name                = var.privDomain
  resource_group_name = azurerm_resource_group.rg["rgCore"].name
  tags                = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "dnsvnetlink" {
  for_each              = local.vnets
  name                  = "${each.key}DnsLink"
  resource_group_name   = azurerm_resource_group.rg["rgCore"].name
  private_dns_zone_name = azurerm_private_dns_zone.dns.name
  registration_enabled  = true
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  depends_on = [
    azurerm_virtual_network.vnet
  ]
}

# vnets Peering
resource "azurerm_virtual_network_peering" "vnetPeerings" {
  for_each                     = local.peerings_map
  name                         = each.key
  resource_group_name          = azurerm_resource_group.rg["rgCore"].name
  virtual_network_name         = azurerm_virtual_network.vnet[each.value.vnet].name
  remote_virtual_network_id    = "/subscriptions/${each.value.subId}/resourceGroups/${each.value.remoteRg}/providers/Microsoft.Network/virtualNetworks/${each.value.remotevnet}"
  allow_forwarded_traffic      = each.value.forwardedTraffic
  allow_gateway_transit        = each.value.gatewayTransit
  allow_virtual_network_access = each.value.vnetAccess
  use_remote_gateways          = each.value.remoteGateway
}


# Subnets 
resource "azurerm_subnet" "subnets" {
  for_each                                       = local.subnets_map
  name                                           = each.key
  resource_group_name                            = azurerm_resource_group.rg["rgCore"].name
  virtual_network_name                           = azurerm_virtual_network.vnet[each.value.vnet].name
  address_prefixes                               = each.value.addressPrefix
  private_endpoint_network_policies_enabled      = true
  service_endpoints = [
    "Microsoft.AzureCosmosDB",
    "Microsoft.KeyVault",
    "Microsoft.Sql",
    "Microsoft.Storage",
    "Microsoft.ServiceBus",
    "Microsoft.EventHub",
    "Microsoft.ContainerRegistry"
  ]

  dynamic "delegation" {
    for_each = each.value.delegation != "none" ? toset([each.value.delegation]) : [] #{ for k, v in local.subnets_map : k => v if v.Nsg == "true" && v.delegation != "none" }
    content {
      name = "delegation"
      service_delegation {
        name = delegation.value 
      }
    }
  }
  lifecycle {
    ignore_changes = [
      delegation
    ]
  }
}

# Nsg
resource "azurerm_network_security_group" "nsg" {
  for_each            = { for k, v in local.subnets_map : k => v if v.nsg == "true" }
  name                = "nsg${title(each.key)}"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name

  tags = merge(local.defaultTags, each.value.customTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

# Nsg association with subnets
resource "azurerm_subnet_network_security_group_association" "nsgAssociation" {
  for_each                  = { for k, v in local.subnets_map : k => v if v.nsg == "true" }
  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
  depends_on = [
    azurerm_network_security_rule.nsgOutboundRules,
    azurerm_network_security_rule.nsgInboundRules
  ]
}

# NSG rules
resource "azurerm_network_security_rule" "nsgInboundRules" {
  for_each                    = local.nsg_inbound_map
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = each.value.access
  protocol                    = title(each.value.protocol)
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.rg["rgCore"].name
  network_security_group_name = azurerm_network_security_group.nsg[each.value.subnet].name
}

resource "azurerm_network_security_rule" "nsgOutboundRules" {
  for_each                    = local.nsg_outbound_map
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = "Outbound"
  access                      = each.value.access
  protocol                    = title(each.value.protocol)
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.rg["rgCore"].name
  network_security_group_name = azurerm_network_security_group.nsg[each.value.subnet].name
}

resource "azurerm_network_watcher_flow_log" "nsgFlow" {
  for_each             = { for k, v in local.subnets_map : k => v if v.nsg == "true" }
  network_watcher_name = "NetworkWatcher_${lower(azurerm_virtual_network.vnet[azurerm_subnet.subnets[each.key].virtual_network_name].location)}"
  resource_group_name  = azurerm_resource_group.rg["rgCore"].name
  name                 = "nsg${title(each.key)}Flow"
  location             = azurerm_resource_group.rg["rgCore"].location

  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
  storage_account_id        = azurerm_storage_account.log["flowlog"].id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 7
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.defaultLaw.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.defaultLaw.location
    workspace_resource_id = azurerm_log_analytics_workspace.defaultLaw.id
    interval_in_minutes   = 60
  }
}

resource "azurerm_route_table" "routesTables" {
  for_each                      = local.routes_conf
  name                          = "rt${title(each.key)}"
  location                      = azurerm_resource_group.rg["rgCore"].location
  resource_group_name           = azurerm_resource_group.rg["rgCore"].name
  disable_bgp_route_propagation = "false"
  tags                          = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

resource "azurerm_subnet_route_table_association" "routesTablesAssociation" {
  for_each       = local.routes_conf
  subnet_id      = azurerm_subnet.subnets[each.key].id
  route_table_id = azurerm_route_table.routesTables[each.key].id
}

resource "azurerm_route" "udr" {
  for_each               = local.udr_map
  name                   = each.key
  resource_group_name    = azurerm_resource_group.rg["rgCore"].name
  route_table_name       = each.value.rt
  address_prefix         = each.value.destination
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = cidrhost(azurerm_subnet.subnets["AzureFirewallSubnet"].address_prefixes.0, 4)
  # we use (...).address_prefix.0 because address prefix is a list of 1 string, and its index is 0 in the list
  depends_on = [
    azurerm_route_table.routesTables
  ]
}

# VNG Configuration
resource "azurerm_public_ip" "vngErPip" {
  count               = var.deployVngEr == true ? 1 : 0
  name                = "vngErPip"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name

  allocation_method = "Static"
  sku               = "Standard"
  zones             = [ "1","2","3" ]
  tags              = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

resource "azurerm_public_ip" "vngIpsecPip" {
  count               = var.deployVngIpsec == true ? 1 : 0
  name                = "vngIpsecPip"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name

  allocation_method = var.vngIpsecSku == "Basic" ? "Dynamic" : "Static"
  sku               = var.vngIpsecSku == "Basic" ? "Basic" : "Standard"
  zones             = var.vngIpsecSku == "Basic" ? null :["1","2","3"]
  tags              = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

## Virtual Network Gateway for Express Route interconnection
resource "azurerm_virtual_network_gateway" "vngEr" {
  count               = var.deployVngEr == true ? 1 : 0
  name                = "vngEr"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name

  type = "ExpressRoute"

  sku = var.vngErSku

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vngErPip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnets["GatewaySubnet"].id
  }
  tags = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}


## Virtual Network Gateway for IPSec
resource "azurerm_virtual_network_gateway" "vngIpsec" {
  count               = var.deployVngIpsec == true ? 1 : 0
  name                = "vngIpsec"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = var.vngIpsecSku

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vngIpsecPip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnets["GatewaySubnet"].id
  }
  tags = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

###############################################
# Azure Firewall
###############################################

resource "azurerm_public_ip" "firewallPip" {
  count               = var.deployAzureFirewall == true ? 1 : 0
  name                = "firewallPip"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "firewall" {
  count               = var.deployAzureFirewall == true ? 1 : 0
  name                = "firewall"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnets["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.firewallPip[0].id
  }

  sku_tier = "Standard"
  sku_name = "AZFW_VNet"
  zones = ["1", "2", "3"]

  tags = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}

###############################################
# Azure Bastion
###############################################

resource "azurerm_public_ip" "bastionPip" {
  count               = var.deployAzureBastion == true ? 1 : 0
  name                = "bastionPip"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  count               = var.deployAzureBastion == true ? 1 : 0
  name                = "bastion"
  location            = azurerm_resource_group.rg["rgCore"].location
  resource_group_name = azurerm_resource_group.rg["rgCore"].name

  sku = "Standard"
  tunneling_enabled = true

  ip_configuration {
    name                 = "bastionIpConf"
    subnet_id            = azurerm_subnet.subnets["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastionPip[0].id
  }
  tags = merge(local.defaultTags, {})
  lifecycle {
    ignore_changes = [
      tags["provisioningDate"],
    ]
  }
}