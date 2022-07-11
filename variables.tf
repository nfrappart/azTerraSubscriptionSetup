

variable "customerName" {
  type    = string
}

variable "privDomain" {
  type = string
}

variable "pubDomain" {
  type = string
}

# Add as many resource group name you want to deploy
variable "rg" {
  default = [
    "rgCore", #required /!\ do not change name
    "rgBackup", #required /!\ do not change name
    "rgSecrets",  #required /!\ do not change name
  ]
}

variable "location" {
  type = string
}

variable "backupPolicies" {
  default = {
    "8d"  = "8",
    "15d" = "15",
    "90d" = "90"
  }
}

variable "deployAzureBastion" {
  default = false
}
variable "deployAzureFirewall" {
  default = false
}

variable "deployVngIpsec" {
  default = false
}

variable "vngIpsecSku" {
  default = "VpnGw1AZ"
}

variable "deployVngEr" {
  default = false
}

variable "vngErSku" {
  default = "ErGw1AZ"
}

variable "myTags" {
  default = {}
}