### Split-horizon Azure DNS zones (with private zone resolvers)

Deploy public and private Azure DNS Zones and virtual network with highly available resolvers.

Based on https://github.com/Azure/azure-quickstart-templates/tree/master/301-dns-forwarder, but for Terraform and with HA.

#### TODO

- Add NSG rules for ports 53/22
- Add support for existing virtual network / subnet
- Support (default) configuration without public IPs
- Support regions without AZ
- Convert into module
- Support private-only zones?
- Improve README
