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

resource "azurerm_lb" "meu_loadbalance" {
  name                = "test"
  location            = azurerm_resource_group.meu_grupo_de_recursos.location
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.meu_PIP.id
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
  loadbalancer_id     = azurerm_lb.meu_loadbalance.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name            = azurerm_resource_group.meu_grupo_de_recursos.name
  name                           = "ssh"
  loadbalancer_id                = azurerm_lb.meu_loadbalance.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_probe" "meu_http_probe" {
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
  loadbalancer_id     = azurerm_lb.meu_loadbalance.id
  name                = "meu_http_probe"
  protocol            = "Http"
  request_path        = "/health"
  port                = 80
}

resource "azurerm_virtual_machine_scale_set" "minha_maquina_virtual" {
  name                = "MinhaMaquinaVirtual"
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
  location            = azurerm_resource_group.meu_grupo_de_recursos.location
  
  upgrade_policy_mode  = "Manual"

  sku {
    name     = "Standard_F2"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "testvm"
    admin_username       = "wordpressuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/wordpressuser/.ssh/authorized_keys"
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet_interna.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.lbnatpool.id]
    }
  }

  tags = {
    environment = "Dev"
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