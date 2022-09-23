
provider "azurerm" {
  features {}
}
terraform {
  required_providers {
    azurerm = {
      version = "3.24.0"
    }
    random  = {}
  }
}
