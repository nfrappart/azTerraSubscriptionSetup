locals {
  prefix = substr(join("", regexall("[a-z]+", lower(var.customerName))), 0, 8)
  defaultTags = merge({
    provisioningDate = timestamp(),
    provisioningMode = "Terraform"
  }, var.myTags)
  rg = { for i in var.rg : i=>var.location}
  networks_conf = jsondecode(file("networks.json"))
  vnets = { for k, v in local.networks_conf :
    k => {
      addressSpace = v.address_space,
      dnsServers   = v.dns_servers
    }
  }
  peerings_list = flatten([for vnet_key, vnet_value in local.networks_conf :
    [for k, v in vnet_value.peerings : {
      peeringName      = k,
      vnet             = vnet_key,
      remotevnet       = v.remote_vnet,
      remoteRg         = v.resource_group_name,
      forwardedTraffic = v.allow_forwarded_traffic,
      gatewayTransit   = v.allow_gateway_transit,
      vnetAccess       = v.allow_virtual_network_access,
      remoteGateway    = v.use_remote_gateways,
      subId            = v.subscription_id
      }
    ]
    ]
  )
  peerings_map = { for i in local.peerings_list :
    i.peeringName => {
      vnet             = i.vnet,
      remotevnet       = i.remotevnet,
      remoteRg         = i.remoteRg,
      forwardedTraffic = i.forwardedTraffic,
      gatewayTransit   = i.gatewayTransit,
      vnetAccess       = i.vnetAccess,
      remoteGateway    = i.remoteGateway,
      subId            = i.subId
    }
  }
  subnets_list = flatten([for vnet_key, vnet_value in local.networks_conf :
    [for k, v in vnet_value.subnets : {
      vnet            = vnet_key,
      subnetName      = k,
      addressPrefix   = v.subnetAddressPrefix,
      nsg             = v.nsg,
      delegation      = v.delegation,
      routesToFirewall      = v.routesToFirewall,
      customTags      = v.customTags
      }
    ]
    ]
  )
  subnets_map = { for i in local.subnets_list :
    i.subnetName => {
      vnet            = i.vnet,
      addressPrefix   = i.addressPrefix,
      nsg             = i.nsg,
      delegation      = i.delegation,
      routesToFirewall = i.routesToFirewall,
      customTags      = i.customTags
    }
  }
  routes_conf = { for k, v in local.subnets_map :
    k => {
      routesToFirewall = v.routesToFirewall, customTags = v.customTags, nsg = v.nsg
    } if v.routesToFirewall != {}
  }

  udr_list = flatten([for k, v in local.subnets_map :
    [for k_udr, v_udr in v.routesToFirewall : {
      udr             = "${k}To${title(k_udr)}",
      rt              = "rt${title(k)}",
      destination     = v_udr
      }
    ]
  ])
  udr_map = { for k, v in local.udr_list :
    v.udr => v
  }
  nsg_list = flatten([for vnet_key, vnet_value in local.networks_conf :
    [for k, v in vnet_value.subnets : {
      subnetName = k,
      inbound    = v.inbound,
      outbound   = v.outbound,
      nsg        = v.nsg
      }
      if v.nsg == "true"
    ]
  ])
  nsg_map = { for k, v in local.nsg_list :
    v.subnetName => {
      nsg      = v.nsg,
      inbound  = v.inbound,
      outbound = v.outbound
    }
  }
  nsg_inbound_list = flatten([for k, v in local.nsg_map : 
    [for k_rule, v_rule in v.inbound : { 
        subnet = k, 
        name = v_rule.name, 
        access = v_rule.access, 
        destination_port_range = v_rule.destination_port_range, 
        destination_address_prefix = v_rule.destination_address_prefix, 
        protocol = v_rule.protocol, 
        source_address_prefix = v_rule.source_address_prefix, 
        source_port_range = v_rule.source_port_range, 
        priority = k_rule }
    ]
  ])
  nsg_inbound_map  = { for i in local.nsg_inbound_list : 
    "${i.subnet}-${i.priority}" => { 
        subnet = i.subnet, 
        priority = i.priority, 
        access = i.access, 
        protocol = i.protocol, 
        name = i.name, 
        destination_port_range = i.destination_port_range, 
        destination_address_prefix = i.destination_address_prefix, 
        source_address_prefix = i.source_address_prefix, 
        source_port_range = i.source_port_range 
    } 
  }
  nsg_outbound_list = flatten([for k, v in local.nsg_map : 
    [for k_rule, v_rule in v.outbound : { 
        subnet = k, 
        name = v_rule.name, 
        access = v_rule.access, 
        destination_port_range = v_rule.destination_port_range, 
        destination_address_prefix = v_rule.destination_address_prefix, 
        protocol = v_rule.protocol, 
        source_address_prefix = v_rule.source_address_prefix, 
        source_port_range = v_rule.source_port_range, 
        priority = k_rule }
    ]
  ])
  nsg_outbound_map  = { for i in local.nsg_outbound_list : 
    "${i.subnet}-${i.priority}" => { 
        subnet = i.subnet, 
        priority = i.priority, 
        access = i.access, 
        protocol = i.protocol, 
        name = i.name, 
        destination_port_range = i.destination_port_range, 
        destination_address_prefix = i.destination_address_prefix, 
        source_address_prefix = i.source_address_prefix, 
        source_port_range = i.source_port_range 
    } 
  }
}