provider "azurerm" {
  version = "=2.40.0"
  features {}
}

resource "azurerm_resource_group" "meu_grupo_de_recursos" {
  name     = "meu_grupo_de_recursos"
  location = "Brazil South"
}

resource "azurerm_virtual_network" "minha_rede" {
  name                = "minha_rede"
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
  location            = azurerm_resource_group.meu_grupo_de_recursos.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_interna" {
  name                 = "subnet_interna"
  resource_group_name  = azurerm_resource_group.meu_grupo_de_recursos.name
  virtual_network_name = azurerm_virtual_network.minha_rede.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "meu_PIP" {
  name                = "meu-PIP"
  location            = azurerm_resource_group.meu_grupo_de_recursos.location
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
  allocation_method   = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_network_interface" "interface" {
  name                = "test-nic"
  location            = azurerm_resource_group.meu_grupo_de_recursos.location
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name

  ip_configuration {
    name                          = "configuration1"
    subnet_id                     = azurerm_subnet.subnet_interna.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.meu_PIP.id
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "minha_maquina_virtual" {
  name                = "MinhaMaquinaVirtual"
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
  location            = azurerm_resource_group.meu_grupo_de_recursos.location
  sku                 = "Standard_F2"
  instances           = 1
  admin_username      = "adminuser"

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "interface_rede"
    primary = true

    ip_configuration {
      name      = "interna"
      primary   = true
      subnet_id = azurerm_subnet.subnet_interna.id
    }
  }
}

data "azurerm_public_ip" "meu_PIP" {
  name                = azurerm_public_ip.meu_PIP.name
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
}

output "public_ip_address" {
  value = data.azurerm_public_ip.meu_PIP.ip_address
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_scale_set