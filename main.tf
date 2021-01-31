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

resource "azurerm_public_ip" "mysql_PIP" {
  name                = "mysql-PIP"
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

resource "azurerm_virtual_machine_scale_set" "meu_conjunto_de_maquinas_wordpress" {
  name                = "MeuConjuntoDeMaquinasWordpress"
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

resource "azurerm_network_security_group" "grupo_de_seguranca_wordpress" {
  name                = "grupo-de-seguranca-wordpress"
  location            = azurerm_resource_group.meu_grupo_de_recursos.location
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name

# Criei esse acesso para poder visualizar a máquina do banco e poder utilizá-la para visualizar as demais máquinas
  security_rule {
    name                       = "MySQL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

    security_rule {
    name                       = "SSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }



  tags = {
    environment = "Dev"
  }
}


resource "azurerm_network_interface" "interface_rede_mysql" {
  name                = "interface-rede-mysql"
  location            = azurerm_resource_group.meu_grupo_de_recursos.location
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_interna.id
    public_ip_address_id          = azurerm_public_ip.mysql_PIP.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost("10.0.2.4/24", 4)
  }
}

resource "azurerm_network_interface_security_group_association" "associacao" {
  network_interface_id      = azurerm_network_interface.interface_rede_mysql.id
  network_security_group_id = azurerm_network_security_group.grupo_de_seguranca_wordpress.id
}

resource "azurerm_linux_virtual_machine" "mysql_machine" {
  name                = "mysql-machine"
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
  location            = azurerm_resource_group.meu_grupo_de_recursos.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.interface_rede_mysql.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

}

data "azurerm_public_ip" "meu_PIP" {
  name                = azurerm_public_ip.meu_PIP.name
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
  depends_on          = [azurerm_virtual_machine_scale_set.meu_conjunto_de_maquinas_wordpress,]
}

output "public_ip_address" {
  value = data.azurerm_public_ip.meu_PIP.ip_address
}

data "azurerm_public_ip" "mysql_PIP" {
  name                = azurerm_public_ip.mysql_PIP.name
  resource_group_name = azurerm_resource_group.meu_grupo_de_recursos.name
  depends_on          = [azurerm_linux_virtual_machine.mysql_machine,]
}

output "public_ip_address_mysql" {
  value = data.azurerm_public_ip.mysql_PIP.ip_address
}

resource "null_resource" "para_uso" {
  provisioner "remote-exec" {

    # Para usar a chave é necessário descriptografá-la: openssl rsa -in id_rsa -out id_rsa.insecure
    inline = [
      "sudo apt-get update",
      "sudo apt-get --yes --force-yes install docker.io",
      "sudo docker run -p 3306:3306 --name wordpress-mysql --restart always -e MYSQL_ROOT_PASSWORD=jhjggykjhd85d83h -e MYSQL_DATABASE=wordpress -e MYSQL_USER=usr-wordpress -e MYSQL_PASSWORD=jhjggykjhd85d83h -d mysql:5.7",
    ]

    connection {
        host = data.azurerm_public_ip.mysql_PIP.ip_address
        user = "adminuser"
        type = "ssh"
        private_key = file("~/.ssh/id_rsa.insecure")
        timeout = "1m"
        agent = true
    }
  }
}