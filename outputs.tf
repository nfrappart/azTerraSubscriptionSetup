#Module Output
output "rg" {
  value = azurerm_resource_group.rg
}
output "vnet" {
  value = azurerm_virtual_network.vnet
}
output "vnetPeering" {
  value = azurerm_virtual_network_peering.vnetPeerings
}
output "subnet" {
  value = azurerm_subnet.subnets
}
output "nsg" {
  value = azurerm_network_security_group.nsg
}
output "dns" {
  value = azurerm_dns_zone.dns
}
output "privateDns" {
  value = azurerm_private_dns_zone.dns
}
output "rsv" {
  value = azurerm_recovery_services_vault.rsv
}
output "log" {
  value = azurerm_storage_account.log
  sensitive = true
}
output "kv" {
  value = azurerm_key_vault.kvCore
}