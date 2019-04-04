### Split-horizon Azure DNS zones (with private zone resolvers)

Deploy public and private Azure DNS Zones and virtual network with highly available resolvers.

#### Why?

Currently, zone delegation for Private DNS Zones on Azure is not supported. It's in the roadmap, but timing is unknown. This module enables _zone delegation for private on-premises resolvers_ already now, by deploying recursive resolver VMs to a private resolution network.

Based on https://github.com/Azure/azure-quickstart-templates/tree/master/301-dns-forwarder, but for Terraform and with HA.

#### What?

The module will, depending on the configuration, deploy:
- Zero or more _public_ DNS Zones into `${var.prefix}-public-zones` resource group. The group will only be created if `var.public_zones` length is greater than 0.
- Zero or more _private_ DNS Zones into `${var.prefix}-private-zones` resource group.
- One virtual network, subnet and network security group
- One or more resolver VMs into the subnet with `bind` configured to recursively resolve all DNS queries using Azure's standard `168.63.129.16`.

_Only Azure regions with Availability Zones are supported._

#### How?

`main.tf`
```hcl

module "dns" {
  source  = "uncleyo/azurerm/dns"
  version = "tbd"

  # required variables:

  location = "West Europe"
  public_zones = [
    "example.org"
  ]
  private_zones = [
    "example.org",
    "local.only"
  ]
  resolver_vm_admin_username = "admin"
  resolver_vm_admin_ssh_pub_key_file = "~/.ssh/id_rsa.pub"

  # optional variables with default values:

  prefix = "dns"
  tags = {}
  debug_enable_resolver_public_ips = false
  availability_zones = [1, 2, 3]
  resolver_count = 2
  resolver_vnet_prefix = "10.53.53.0/24"
  resolver_subnet_prefix = "10.53.53.0/24"
  resolver_ip_offset = 4
  resolver_vm_size = Standard_B1ls
  resolver_vm_ssh_client_whitelist = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ]
  resolver_vm_ssh_client_whitelist = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ]
  resolver_client_whitelist = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ]
}
```

#### TODO:

- Add support for existing virtual network / subnet?
