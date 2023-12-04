terraform {

  cloud {
    organization = "pirjantzpro"

    workspaces {
      name = "azure-workspace"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
}

resource "azurerm_resource_group" "abc-rg" {
  name     = "abc-resources"
  location = "West Europe"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "abc-vn" {
  name                = "abc-network"
  resource_group_name = azurerm_resource_group.abc-rg.name
  location            = azurerm_resource_group.abc-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }

}

resource "azurerm_subnet" "abc-subnet1" {
  name                 = "abc-subnet1"
  resource_group_name  = azurerm_resource_group.abc-rg.name
  virtual_network_name = azurerm_virtual_network.abc-vn.name
  address_prefixes     = ["10.123.1.0/24"]

}

resource "azurerm_network_security_group" "abc-sg" {
  name                = "abc-sg"
  location            = azurerm_resource_group.abc-rg.location
  resource_group_name = azurerm_resource_group.abc-rg.name

  tags = {
    environment = "dev"
  }

}

resource "azurerm_network_security_rule" "abc-dev-rule" {
  name                        = "abc-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.abc-rg.name
  network_security_group_name = azurerm_network_security_group.abc-sg.name
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.abc-subnet1.id
  network_security_group_id = azurerm_network_security_group.abc-sg.id
}

resource "azurerm_public_ip" "abc-ip1" {
  name                = "abc-ip1"
  resource_group_name = azurerm_resource_group.abc-rg.name
  location            = azurerm_resource_group.abc-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "abc-nic" {
  name                = "abc-nic"
  location            = azurerm_resource_group.abc-rg.location
  resource_group_name = azurerm_resource_group.abc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.abc-subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.abc-ip1.id
  }
}

resource "azurerm_linux_virtual_machine" "abc-vm" {
  name                = "abc-vm"
  resource_group_name = azurerm_resource_group.abc-rg.name
  location            = azurerm_resource_group.abc-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.abc-nic.id,
  ]
  custom_data = filebase64("${path.module}/customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("${path.module}/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl",{
      hostname = self.public_ip_address
      user = self.admin_username
      identityfile = "${abspath(path.root)}/id_rsa"
    })
    interpreter = ["/bin/bash", "-c"]
  }

  tags = {
    environment = "dev"
  }

}

data "azurerm_public_ip" "abc-ip1-data" {
  name = azurerm_public_ip.abc-ip1.name
  resource_group_name = azurerm_resource_group.abc-rg.name

}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.abc-vm.name}: ${data.azurerm_public_ip.abc-ip1-data.ip_address}"
}