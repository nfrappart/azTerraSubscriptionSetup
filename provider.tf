
provider "azurerm" {
  features {}
}
terraform {
  required_providers {
    azurerm = {
      version = "3.10.0"
    }
    random  = {}
  } /*
  backend "azurerm" {
    #storage_account_name = ""
    #container_name       = ""
    key                  = "coreservices.tfstate"
  }*/
}
