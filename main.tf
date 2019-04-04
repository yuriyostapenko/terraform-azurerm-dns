resource "azurerm_resource_group" "public" {
  count = "${length(var.public_zones) > 0 ? 1 : 0}"
  name     = "${var.prefix}-public"
  location = "${var.location}"
  tags = "${var.tags}"
}

resource "azurerm_resource_group" "private" {
  name     = "${var.prefix}-private"
  location = "${var.location}"
  tags = "${var.tags}"
}

resource "azurerm_virtual_network" "resolver" {
  name                = "${var.prefix}-resolver-network"
  resource_group_name = "${azurerm_resource_group.private.name}"
  location            = "${azurerm_resource_group.private.location}"
  address_space       = ["${var.resolver_vnet_prefix}"]
  tags = "${var.tags}"
}

resource "azurerm_network_security_group" "resolver" {
  name                = "${var.prefix}-resolver-nsg"
  location            = "${azurerm_resource_group.private.location}"
  resource_group_name = "${azurerm_resource_group.private.name}"
  tags = "${var.tags}"
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "SSH"
  priority                    = 122
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes       = "${var.resolver_vm_ssh_client_whitelist}"
  destination_address_prefix  = "${var.resolver_subnet_prefix}"
  resource_group_name         = "${azurerm_resource_group.private.name}"
  network_security_group_name = "${azurerm_network_security_group.resolver.name}"
}

resource "azurerm_network_security_rule" "dns" {
  name                        = "DNS"
  priority                    = 153
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefixes       = "${var.resolver_client_whitelist}"
  destination_address_prefix  = "${var.resolver_subnet_prefix}"
  resource_group_name         = "${azurerm_resource_group.private.name}"
  network_security_group_name = "${azurerm_network_security_group.resolver.name}"
}

resource "azurerm_subnet" "resolver" {
  name                      = "${var.prefix}-resolver-subnet"
  resource_group_name       = "${azurerm_resource_group.private.name}"
  virtual_network_name      = "${azurerm_virtual_network.resolver.name}"
  address_prefix            = "${var.resolver_subnet_prefix}"
  # even though this causes deprecation warning, it must be here, too, otherwise
  # Terraform will keep adding/removing the association on each apply
  network_security_group_id = "${azurerm_network_security_group.resolver.id}"
}

resource "azurerm_subnet_network_security_group_association" "resolver" {
  subnet_id                 = "${azurerm_subnet.resolver.id}"
  network_security_group_id = "${azurerm_network_security_group.resolver.id}"
}

resource "azurerm_dns_zone" "public" {
  count               = "${length(var.public_zones)}"
  name                = "${var.public_zones[count.index]}"
  resource_group_name = "${azurerm_resource_group.public.name}"
  zone_type           = "Public"
  tags = "${var.tags}"
}

resource "azurerm_dns_zone" "private" {
  count                           = "${length(var.private_zones)}"
  name                            = "${var.private_zones[count.index]}"
  resource_group_name             = "${azurerm_resource_group.private.name}"
  zone_type                       = "Private"
  resolution_virtual_network_ids  = [
    "${azurerm_virtual_network.resolver.id}"
  ]
  tags = "${var.tags}"
}

resource "azurerm_public_ip" "resolver" {
  count               = "${var.debug_enable_resolver_public_ips ? var.resolver_count : 0}"
  name                = "${var.prefix}-resolver-${format("%02d", count.index + 1)}-public-ip"
  location            = "${azurerm_resource_group.private.location}"
  resource_group_name = "${azurerm_resource_group.private.name}"
  allocation_method   = "Static"
  zones = "${list(element(var.availability_zones, count.index))}"
  tags = "${var.tags}"
}

resource "azurerm_network_interface" "resolver" {
  count               = "${var.resolver_count}"
  name                = "${var.prefix}-resolver-${format("%02d", count.index + 1)}-nic"
  location            = "${azurerm_resource_group.private.location}"
  resource_group_name = "${azurerm_resource_group.private.name}"

  ip_configuration {
    name                          = "${var.prefix}-resolver-${format("%02d", count.index + 1)}-private-ip"
    subnet_id                     = "${azurerm_subnet.resolver.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "${cidrhost(var.resolver_subnet_prefix, count.index + var.resolver_ip_offset)}"
    public_ip_address_id          = "${var.debug_enable_resolver_public_ips ? element(coalescelist(azurerm_public_ip.resolver.*.id, list("")), count.index) : ""}"
  }

  tags = "${var.tags}"
}

resource "azurerm_virtual_machine" "resolver" {
  count = "${var.resolver_count}"
  name                  = "${var.prefix}-resolver-${format("%02d", count.index + 1)}"
  location              = "${azurerm_resource_group.private.location}"
  resource_group_name   = "${azurerm_resource_group.private.name}"
  network_interface_ids = ["${element(azurerm_network_interface.resolver.*.id, count.index)}"]
  vm_size               = "${var.resolver_vm_size}"

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.prefix}-resolver-${format("%02d", count.index + 1)}-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.prefix}-resolver-${format("%02d", count.index + 1)}"
    admin_username = "${var.resolver_vm_admin_username}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys = [{
      path = "/home/${var.resolver_vm_admin_username}/.ssh/authorized_keys"
      key_data = "${file(var.resolver_vm_admin_ssh_pub_key_file)}"
    }]
  }

  zones = "${list(element(var.availability_zones, count.index))}"

  tags = "${var.tags}"
}

resource "azurerm_virtual_machine_extension" "resolver" {
  count = "${var.resolver_count}"
  name                 = "${var.prefix}-resolver-${format("%02d", count.index + 1)}-bind-setup"
  location             = "${azurerm_resource_group.private.location}"
  resource_group_name  = "${azurerm_resource_group.private.name}"
  virtual_machine_name = "${element(azurerm_virtual_machine.resolver.*.name, count.index)}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
      "script": "${base64encode("CLIENT_WHITELIST=${join("\\;", var.resolver_client_whitelist)}\n\n${file("${path.module}/bind_setup.sh")}")}"
    }
SETTINGS

  tags = "${var.tags}"
}
