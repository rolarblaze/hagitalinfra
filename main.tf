terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}


provider "azurerm" {
  features {}
  subscription_id = "23d9c7c6-346c-4436-9831-fabb09eafbb9"
  client_id       = "5ce5e932-9c35-4581-b89f-26ae2fcf5b85"
}

resource "azurerm_resource_group" "mtc_grp" { 
  name     = "mtc_resource"
  location = "Central US"
  tags = {
    Name = "Prod"
  }
}

resource "azurerm_virtual_network" "mtc_vnet" {
  name                = "myvent"
  resource_group_name = azurerm_resource_group.mtc_grp.name
  location            = azurerm_resource_group.mtc_grp.location
  address_space       = ["10.0.0.0/16"]

}

# Creating a subnet 
resource "azurerm_subnet" "public_subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.mtc_grp.name
  virtual_network_name = azurerm_virtual_network.mtc_vnet.name
  address_prefixes     = ["10.0.0.0/24"]

}

# creating a private subnet
resource "azurerm_subnet" "private_subnet" {
  name                 = "Private_subnet"
  resource_group_name  = azurerm_resource_group.mtc_grp.name
  virtual_network_name = azurerm_virtual_network.mtc_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

#creating a network security group 
resource "azurerm_network_security_group" "mtc_nsg" {
  name                = "ServerNSG"
  location            = azurerm_resource_group.mtc_grp.location
  resource_group_name = azurerm_resource_group.mtc_grp.name
  tags = {
    environment = "production"
  }

}

resource "azurerm_network_security_rule" "mtc_nsgr" {
  name                       = "MySecurityRule"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"

    resource_group_name = azurerm_resource_group.mtc_grp.name
    network_security_group_name = azurerm_network_security_group.mtc_nsg.name
}


resource "azurerm_subnet_network_security_group_association" "mtc_nsga" {

  subnet_id                 = azurerm_subnet.public_subnet.id
  network_security_group_id = azurerm_network_security_group.mtc_nsg.id
}


#Create a public IP address 
resource "azurerm_public_ip" "mtc_ip" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = azurerm_resource_group.mtc_grp.name
  location            = azurerm_resource_group.mtc_grp.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

#Creating a NIC

resource "azurerm_network_interface" "mtc_nic" {
  name                = "mtc_nic"
  resource_group_name = azurerm_resource_group.mtc_grp.name
  location            = azurerm_resource_group.mtc_grp.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.mtc_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "mtc_vm" {
  name                  = "example-machine"
  resource_group_name   = azurerm_resource_group.mtc_grp.name
  location              = azurerm_resource_group.mtc_grp.location
  size                  = "Standard_F2"
  admin_username        = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mtc_nic.id,
    ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}