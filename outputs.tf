
output "public_nameservers" {
  description = "Map with public DNS Zone names as keys and lists of assigned name servers as values."
  value       = ["${zipmap(azurerm_dns_zone.public.*.name, azurerm_dns_zone.public.*.name_servers)}"]
}

output "private_resolver_ips" {
  description = "List of private IPs of resolver VMs"
  value       = ["${azurerm_network_interface.resolver.*.private_ip_address}"]
}
