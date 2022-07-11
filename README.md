# Azure Subscription Setup Module
## What it does:
This module creates all ressources to build a Hub & Spoke network architecture
- 3 Resource Groups
  - rgCore
  - rgSecrets
  - rgBackup
- n Vnet* 
- n Peerings*
- n subnet*
- azure firewall (if corresponding variable set to `true`)
- azure bastion (if corresponding variable set to `true`)
- azure vng ipsec (if corresponding variable set to `true`)
- azure vng er (if corresponding variable set to `true`)
- 1 storage account for bootdiags
- 1 automation account
- 1 log analytics workspace
- 1 recovery service vault with 3 standard policies

*Network configuration is based on `networks.json` file. See below.

## Required file(s):
- networks.json*: containing all your network configuration (vnet, subnet, nsg, rules, etc.)
<br>
/!\ Copy `_sample_networks.json` in your project folder and edit it to suit your needs /!\
the folowing entries must not be removed if you decide to deploy managed services like bastion, vnet gateway, firewall:
- AzureFirewallSubnet
- AzureBastionSubnet
- GatewaySubnet
*see below for more detailed information about networks.json

## How to use it:
```hcl

provider "azurerm" {
  features {}
}
terraform {
  required_providers {
    azurerm = {
      version = "3.10.0"
    }
  }
}

data "azurerm_client_config" "current" {}

module "subsetup" {
  source = "github.com/nfrappart/terraform-az-modules/azTerraSubscriptionSetup?ref=v1.0.0"
  customerName        = "natedemo"   #required.
  privDomain = "priv.natedemo.fr"    #required.
  pubDomain = "natedemo.fr"          #required.
  deployVngIpsec      = false        #optional. Defaults to false.
  vngIpsecSku         = "VpnGw1AZ"   #optional. Defaults to VpnGw1AZ.
  vngErSku            = "ErGw1AZ"    #optional. Defaults to ErGw1AZ.
  deployVngEr         = false        #optional. Defaults to false.
  deployAzureBastion  = false        #optional. Defaults to false.
  deployAzureFirewall = false        #optional. Defaults to false.
  myTags = {                         #optional. Defaults to empty map.
    "provisionedBy" = "Nate",
    "usage" = "demo"
  }
}

# Most module ressources are available as output. 
# To use them, you need to specify the instance name (refer to the names you define in the json file)
# Then specify the usual resource attribute
# Example:
output "GatewaySubnet" {
  value = module.subsetup.subnet["GatewaySubnet"].address_prefixes
}

```

## Configuration file: networks.json
The json file has a predefined structure like below. A full example is provided in the next section.

The Vnet part looks like this:
```json
{
  "hub":{
    "address_space":["10.10.0.0/16"],
    "dns_servers":[],
    "peerings":{
      (redacted...)
    },
    "subnets":{
      (redacted...)
    }
  },
  "spoke1":{
    (redacted...)
  },
  "spoke2":{
    (redacted...)
  }
}
```
The keys will be used to name your VNets. You can add as many bloc as you want as long as they hold all the necessary attributes.

`dns_server` attribute can be an empty list, in which case the VNet will use Azure default DNS.
`peerings`can be an empty map, but since the whole idea is to build a Hub&Spoke, you will obviously want to fill them.

Herre is how it looks:
```json
{
  (redacted...)
    "peerings":{
      "peerHubToSpoke1":{
        "resource_group_name":"rgCore",
        "remote_vnet":"spoke1",
        "subscription_id":"<your_sub_id>",
        "allow_virtual_network_access":"true",
        "allow_forwarded_traffic":"true",
        "allow_gateway_transit":"true",
        "use_remote_gateways":"false"
      },
      "peerHubToSpoke2":{
        "resource_group_name":"rgCore",
        "remote_vnet":"spoke1",
        "subscription_id":"<your_sub_id>",
        "allow_virtual_network_access":"true",
        "allow_forwarded_traffic":"true",
        "allow_gateway_transit":"true",
        "use_remote_gateways":"false"
      }
    }
  (redacted...)
}
```
Choose your options depending on your needs, but you can probably use them as above if you're starting. 

Don't forget to fill in your remote vnet `subscription_id`.
> subscription id is a trick to allow you to peer Vnets in different subscriptions. If all your infrastructure is in the same subscription, then use the same everywhere for all your peerings

Keys will be used as name for your peerings.

`resource_group_name` is the resource group where your remote VNet is located.

For your Hub VNet, you will need as many peerings as spoke Vnets you have. On the other hand, in a spoke VNet you will most likely only need a peering toward hub VNet like so:

```json
{
  (redacted...)
    "peerings":{
      "peerSpoke1ToHub":{
        "resource_group_name":"rgCore",
        "remote_vnet":"hub",
        "subscription_id":"<your_sub_id>",
        "allow_virtual_network_access":"true",
        "allow_forwarded_traffic":"true",
        "allow_gateway_transit":"false",
        "use_remote_gateways":"false"
      }
    }
  (redacted...)
} 
```

The Subnet attribute is obviously the most complete one, see a redacted version here:
```json
{
  (redacted...)
    "subnets":{
      "adminHubSubnet":{
        "subnetAddressPrefix":["10.10.0.0/25"],
        "nsg":"true",
        "delegation":"none",
        "customTags":{
          (redacted...)
        },
        "inbound":{
          "999":{
            "name":"tempAllowVnetInBound",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1000":{
            "name":"PermitIcmp",
            "access":"Allow",
            "protocol":"Icmp",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "4095":{
            "name":"PermitAzureLB",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"AzureLoadBalancer",
            "destination_address_prefix":"*"
          },
          "4096":{
            "name":"DenyANY",
            "access":"Deny",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"*"
          }
        },
        "outbound":{},
        "nextHopFirewall":"false",
        "routesToFirewall":{}
      },
      "AzureFirewallSubnet":{
        "subnetAddressPrefix":["10.10.0.128/26"],
        "nsg":"false",
        "delegation":"none",
        "customTags":{
          (redacted...)
        },
        "routesToFirewall":{}
      }
    }
  (redacted...)
}
```
Let's dive into what we have here.

In the `subnet` bloc, the key will be used as your subnet name.

The `subnetAddressPrefix`is obviously required as your CIDR bloc for said subnet.

`nsg` attribute is a flag, if set to true, a Network Security Group will be provisioned and associated with the subnet. In that case, you **have to** provide `Inbound` and `Outbound` attribute which will define your NSG rules. Both of these can be empty maps if you don't know yet what rule to apply

`delegation` is for the case your subnet is to be delegated to a managed service, like some managed services (like flexible servers or container instances).

> In the sample below, I create `AzureBastionSubnet` and the Inbound/Outbound section provide all the required rules for secured Bastion Service.

`customTags` is a simple map to add your personalized default tags.

`routesToFirewall` is a map which, when not empty, will populate UDR and Route Table for the related subnet. This attribute will use keys as udr name in the format `subnetNameToKeyname`, and value as destination network (value must be a valid CIDR block), using Azure Firewall as next hop IP.

**OBVIOUSLY** to use this, you need to set the input variable `deployAzureFirewall` to `true` and provide an `AzureFirewallSubnet` in you subnet bloc (preferably in your hub VNet).

## Example with hub and one spoke:
```json
{
  "hub":{
    "address_space":["10.10.0.0/16"],
    "dns_servers":[],
    "peerings":{
      "peerHubToSpoke1":{
        "resource_group_name":"rgCore",
        "remote_vnet":"spoke1",
        "subscription_id":"<your_sub_id>",
        "allow_virtual_network_access":"true",
        "allow_forwarded_traffic":"true",
        "allow_gateway_transit":"true",
        "use_remote_gateways":"false"
      }
    },
    "subnets":{
      "adminHubSubnet":{
        "subnetAddressPrefix":["10.10.0.0/25"],
        "nsg":"true",
        "delegation":"none",
        "customTags":{
          "Contact":"",
          "Comment":""
        },
        "inbound":{
          "999":{
            "name":"tempAllowVnetInBound",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1000":{
            "name":"PermitIcmp",
            "access":"Allow",
            "protocol":"Icmp",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "4095":{
            "name":"PermitAzureLB",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"AzureLoadBalancer",
            "destination_address_prefix":"*"
          },
          "4096":{
            "name":"DenyANY",
            "access":"Deny",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"*"
          }
        },
        "outbound":{},
        "routesToFirewall":{}
      },
      "AzureFirewallSubnet":{
        "subnetAddressPrefix":["10.10.0.128/26"],
        "nsg":"false",
        "delegation":"none",
        "customTags":{
          "Contact":"",
          "Comment":""
        },
        "routesToFirewall":{}
      },
      "GatewaySubnet":{
        "subnetAddressPrefix":["10.10.0.192/27"],
        "nsg":"false",
        "delegation":"none",
        "customTags":{
          "Contact":"",
          "Comment":""
        },
        "routesToFirewall":{}
      },
      "AzureBastionSubnet":{
        "subnetAddressPrefix":["10.10.0.224/27"],
        "nsg":"true",
        "delegation":"none",
        "customTags":{
          "Contact":"",
          "Comment":""
        },
        "inbound":{
          "1000":{
            "name":"PermitIcmp",
            "access":"Allow",
            "protocol":"Icmp",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1001":{
            "name":"PermitGatewayManagerInbound",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"443",
            "source_address_prefix":"GatewayManager",
            "destination_address_prefix":"*"
          },
          "1002":{
            "name":"PermitBastionCommunication8080Inbound",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"8080",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1003":{
            "name":"PermitBastionCommunication5701Inbound",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"5701",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1004":{
            "name":"PermitBastionHttpsInbound",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"443",
            "source_address_prefix":"Internet",
            "destination_address_prefix":"*"
          },
          "4095":{
            "name":"PermitAzureLbInbound",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"443",
            "source_address_prefix":"AzureLoadBalancer",
            "destination_address_prefix":"*"
          },
          "4096":{
            "name":"DenyAnyInbound",
            "access":"Deny",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"*"
          }
        },
        "outbound":{
          "1000":{
            "name":"PermitSsh",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"22",
            "source_address_prefix":"*",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1001":{
            "name":"PermitRdp",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"3389",
            "source_address_prefix":"*",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1002":{
            "name":"PermitAzureCloud",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"443",
            "source_address_prefix":"*",
            "destination_address_prefix":"AzureCloud"
          },
          "1003":{
            "name":"PermitGetSessionInformation",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"Internet"
          },
          "1004":{
            "name":"PermitBastionCommunication8080Outbound",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"8080",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1005":{
            "name":"PermitBastionCommunication5701Outbound",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"5701",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1006":{
            "name":"InternetOutbound",
            "access":"Allow",
            "protocol":"tcp",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"Internet"
          },
          "4095":{
            "name":"PermitAzureLbOutbound",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"AzureLoadBalancer",
            "destination_address_prefix":"*"
          },
          "4096":{
            "name":"DenyAnyOutbound",
            "access":"Deny",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"*"
          }
        },
        "routesToFirewall":{}
      }
    }
  },
  "spoke1":{
    "address_space":["10.11.0.0/16"],
    "dns_servers":[],
    "peerings":{
      "peerSpoke1ToHub":{
        "resource_group_name":"rgCore",
        "remote_vnet":"hub",
        "subscription_id":"<your_sub_id>",
        "allow_virtual_network_access":"true",
        "allow_forwarded_traffic":"true",
        "allow_gateway_transit":"false",
        "use_remote_gateways":"false"
      }
    },
    "subnets":{
      "adminSpoke1Subnet":{
        "subnetAddressPrefix":["10.11.0.0/25"],
        "nsg":"true",
        "delegation":"none",
        "customTags":{
          "Contact":"",
          "Comment":""
        },
        "inbound":{
          "999":{
            "name":"tempAllowVnetInBound",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1000":{
            "name":"PermitIcmp",
            "access":"Allow",
            "protocol":"Icmp",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "4095":{
            "name":"PermitAzureLB",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"AzureLoadBalancer",
            "destination_address_prefix":"*"
          },
          "4096":{
            "name":"DenyANY",
            "access":"Deny",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"*"
          }
        },
        "outbound":{},
        "routesToFirewall":{}
      },
      "aksSpoke1Subnet":{
        "subnetAddressPrefix":["10.11.252.0/22"],
        "nsg":"true",
        "delegation":"none",
        "customTags":{
          "Contact":"",
          "Comment":""
        },
        "inbound":{
          "999":{
            "name":"tempAllowVnetInBound",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1000":{
            "name":"PermitIcmp",
            "access":"Allow",
            "protocol":"Icmp",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "4095":{
            "name":"PermitAzureLB",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"AzureLoadBalancer",
            "destination_address_prefix":"*"
          },
          "4096":{
            "name":"DenyANY",
            "access":"Deny",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"*"
          }
        },
        "outbound":{},
        "routesToFirewall":{}
      },
      "pgsqlSpoke1Subnet":{
        "subnetAddressPrefix":["10.11.251.128/25"],
        "nsg":"true",
        "delegation":"Microsoft.DBforPostgreSQL/flexibleServers",
        "customTags":{
          "Contact":"",
          "Comment":"Delegated to PgSQL Flexible Servers"
        },
        "inbound":{
          "999":{
            "name":"tempAllowVnetInBound",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1000":{
            "name":"PermitIcmp",
            "access":"Allow",
            "protocol":"Icmp",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "4095":{
            "name":"PermitAzureLB",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"AzureLoadBalancer",
            "destination_address_prefix":"*"
          },
          "4096":{
            "name":"DenyANY",
            "access":"Deny",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"*"
          }
        },
        "outbound":{},
        "routesToFirewall":{}
      },
      "privateEndpointSpoke1Subnet":{
        "subnetAddressPrefix":["10.11.250.0/24"],
        "nsg":"true",
        "delegation":"none",
        "customTags":{
          "Contact":"",
          "Comment":"Reserved to PaaS Private Endpoints"
        },
        "inbound":{
          "999":{
            "name":"tempAllowVnetInBound",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "1000":{
            "name":"PermitIcmp",
            "access":"Allow",
            "protocol":"Icmp",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"VirtualNetwork",
            "destination_address_prefix":"VirtualNetwork"
          },
          "4095":{
            "name":"PermitAzureLB",
            "access":"Allow",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"AzureLoadBalancer",
            "destination_address_prefix":"*"
          },
          "4096":{
            "name":"DenyANY",
            "access":"Deny",
            "protocol":"*",
            "source_port_range":"*",
            "destination_port_range":"*",
            "source_address_prefix":"*",
            "destination_address_prefix":"*"
          }
        },
        "outbound":{},
        "routesToFirewall":{}
      }
    }
  }
}
```