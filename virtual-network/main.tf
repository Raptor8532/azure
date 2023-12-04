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

resource "azurerm_subnet" "abc-subnet" {
  name                 = "abc-subnet1"
  resource_group_name  = azurerm_resource_group.abc-rg.name
  virtual_network_name = azurerm_virtual_network.abc-vn.name
  address_prefixes    = ["10.123.1.0/24"]

}