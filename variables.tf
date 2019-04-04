variable "prefix" {
  type        = "string"
  description = "Prefix to add to all managed resource names. Example: 'test-'."
  default     = "dns"
}

variable "tags" {
  type        = "map"
  description = "Tags to add to all managed resources."
  default     = {}
}

variable "public_zones" {
  type        = "list"
  description = "Public DNS Zone names (domain names)"
}

variable "private_zones" {
  type        = "list"
  description = "Private DNS Zone names (domain names)"
}

variable "location" {
  type        = "string"
  description = "The Azure region in which regional resources should be provisioned (VMs and resolver network)"
}

variable "debug_enable_resolver_public_ips" {
  type        = "string"
  description = "Enable public IP assignment to resolver VMs. For debugging only, requires appropriate resolver_vm_ssh_client_whitelist for SSH to work."
  default     = false
}

variable "availability_zones" {
  type        = "list"
  description = "Numbers of availability zones to use to spread resolvers into. Regious without availability zones are currently not supported."
  default     = [1, 2, 3]
}

variable "resolver_count" {
  type  = "string"
  description = "Number of resolver VMs"
  default = 2
}

variable "resolver_vnet_prefix" {
  type        = "string"
  description = "Resolver virtual network address space"
  default     = "10.53.53.0/24"
}

variable "resolver_subnet_prefix" {
  type        = "string"
  description = "Resolver subnet address space"
  default     = "10.53.53.0/24"
}

variable "resolver_ip_offset" {
  type        = "string"
  description = "IP address offset within the subnet. 4 is the minimum valid value. resolver private IPs will be assigned sequentially starting with offset."
  default     = "4"
}

variable "resolver_vm_size" {
  type        = "string"
  description = "Resolver VM tier and size"
  default     = "Standard_B1ls"
}

variable "resolver_vm_admin_username" {
  type        = "string"
  description = "Resolver VM admin username"
}

variable "resolver_vm_admin_ssh_pub_key_file" {
  type        = "string"
  description = "Resolver VM admin ssh public key path"
}

variable "resolver_vm_ssh_client_whitelist" {
  type        = "list"
  description = "List of CIDR entries of acceptable resolver VM ssh clients"
  default = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ]
}

variable "resolver_client_whitelist" {
  type        = "list"
  description = "List of CIDR entries of acceptable DNS resolver client IPs"
  default = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ]
}
