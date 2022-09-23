

variable "customerName" {
  description = "Customer or Organization name for naming convention."
  type    = string
}

variable "privDomain" {
  description = "Private Domain zone for auto registration."
  type = string
}

variable "pubDomain" {
  description = "Public Domain zone to for your publicly exposed services."
  type = string
}

# Add as many resource group name you want to deploy
variable "rg" {
  description = "List of resource groups to be created - DO NOT remove the 3 default ones."
  default = [
    "rgCore", #required /!\ do not change name
    "rgBackup", #required /!\ do not change name
    "rgSecrets",  #required /!\ do not change name
  ]
}

variable "location" {
  description = "Default location for your resources"
  type = string
}

variable "backupPolicies" {
  description = "Name and corresponding retention for Recovery Service Vault backup policies."
  default = {
    "8d"  = "8",
    "15d" = "15",
    "90d" = "90"
  }
}

variable "deployAzureBastion" {
  description = "Boolean to indicate if you wish to deploy Bastion or not."
  default = false
}
variable "deployAzureFirewall" {
  description = "Boolean to indicate if you wish to deploy Azure Firewall or not."
  default = false
}

variable "deployVngIpsec" {
  description = "Boolean to indicate if you wish to deploy IPSec Virtual Network Gateway or not."
  default = false
}

variable "vngIpsecSku" {
  description = "Sku to be used for above mentioned IPSec VNG."
  default = "VpnGw1AZ"
}

variable "deployVngEr" {
  description = "Boolean to indicate if you wish to deploy Express Route Virtual Network Gateway or not."
  default = false
}

variable "vngErSku" {
  description = "Sku to be used for above mentioned Express Route VNG."
  default = "ErGw1AZ"
}

variable "myTags" {
  description = "Map variable to be set as default tags on every resources in this project."
  default = {}
}