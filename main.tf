resource "azurerm_resource_group" "public" {
  name     = "dns-zones-public"
  location = "${var.location}"
}

resource "azurerm_resource_group" "private" {
  name     = "dns-zones-private"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "resolver" {
  name                = "private-resolver-network"
  resource_group_name = "${azurerm_resource_group.private.name}"
  location            = "${azurerm_resource_group.private.location}"
  address_space       = ["${var.resolver_vnet_prefix}"]
}

resource "azurerm_network_security_group" "resolver" {
  name                = "private-resolver-nsg"
  location            = "${azurerm_resource_group.private.location}"
  resource_group_name = "${azurerm_resource_group.private.name}"
}

resource "azurerm_subnet" "resolver" {
  name                      = "private-resolver-subnet"
  resource_group_name       = "${azurerm_resource_group.private.name}"
  virtual_network_name      = "${azurerm_virtual_network.resolver.name}"
  address_prefix            = "${var.resolver_subnet_prefix}"
  network_security_group_id = "${azurerm_network_security_group.resolver.id}"
}

resource "azurerm_subnet_network_security_group_association" "resolver" {
  subnet_id                 = "${azurerm_subnet.resolver.id}"
  network_security_group_id = "${azurerm_network_security_group.resolver.id}"
}

resource "azurerm_dns_zone" "public" {
  count               = "${length(var.zones)}"
  name                = "${var.zones[count.index]}"
  resource_group_name = "${azurerm_resource_group.public.name}"
  zone_type           = "Public"
}

resource "azurerm_dns_zone" "private" {
  count                           = "${length(var.zones)}"
  name                            = "${var.zones[count.index]}"
  resource_group_name             = "${azurerm_resource_group.private.name}"
  zone_type                       = "Private"
  resolution_virtual_network_ids  = [
    "${azurerm_virtual_network.resolver.id}"
  ]
}

resource "azurerm_public_ip" "resolver" {
  count               = "${var.resolver_count}"
  name                = "resolver-${format("%02d", count.index + 1)}-public-ip"
  location            = "${azurerm_resource_group.private.location}"
  resource_group_name = "${azurerm_resource_group.private.name}"
  allocation_method   = "Static"
  zones = ["${(count.index % 3) + 1}"]
}

resource "azurerm_network_interface" "resolver" {
  count               = "${var.resolver_count}"
  name                = "resolver-${format("%02d", count.index + 1)}-nic"
  location            = "${azurerm_resource_group.private.location}"
  resource_group_name = "${azurerm_resource_group.private.name}"

  ip_configuration {
    name                          = "private-ip"
    subnet_id                     = "${azurerm_subnet.resolver.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "${cidrhost(var.resolver_subnet_prefix, count.index + 4)}"
    public_ip_address_id          = "${element(azurerm_public_ip.resolver.*.id, count.index)}"
  }

  depends_on = ["azurerm_dns_zone.private"]
}

resource "azurerm_virtual_machine" "resolver" {
  count = "${var.resolver_count}"
  name                  = "resolver-${format("%02d", count.index + 1)}"
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
    name              = "resolver-${format("%02d", count.index + 1)}-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "resolver-${format("%02d", count.index + 1)}"
    admin_username = "${var.resolver_vm_admin_username}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys = [{
      path = "/home/${var.resolver_vm_admin_username}/.ssh/authorized_keys"
      key_data = "${file(var.resolver_vm_admin_ssh_pub_key_file)}"
    }]
  }

  zones = ["${(count.index % 3) + 1}"]
}

resource "azurerm_virtual_machine_extension" "resolver" {
  count = "${var.resolver_count}"
  name                 = "bind"
  location             = "${azurerm_resource_group.private.location}"
  resource_group_name  = "${azurerm_resource_group.private.name}"
  virtual_machine_name = "${element(azurerm_virtual_machine.resolver.*.name, count.index)}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
      "script": "${base64encode("CLIENT_WHITELIST=${join("\\;", var.resolver_client_whitelist)}\n\n${file("bind_setup.sh")}")}"
    }
SETTINGS

}
