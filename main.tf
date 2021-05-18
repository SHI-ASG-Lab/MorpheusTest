variable "TF_VAR_ARM_CLIENT_ID" {
  type = string
  sensitive = true
}
variable "TF_VAR_ARM_CLIENT_SECRET" {
  type = string
  sensitive = true
}
variable "TF_VAR_ARM_SUBSCRIPTION_ID" {
  type = string
  sensitive = true
}
variable "TF_VAR_ARM_TENANT_ID" {
  type = string
  sensitive = true
}

# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.46.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.TF_VAR_ARM_SUBSCRIPTION_ID
  client_id       = var.TF_VAR_ARM_CLIENT_ID
  client_secret   = var.TF_VAR_ARM_CLIENT_SECRET
  tenant_id       = var.TF_VAR_ARM_TENANT_ID
}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = "LAB-MorpheusMade-RG"
  location = "southcentralus"
  tags     = {
      Owner = "JIsley"
      Requestor = "nil"
      SP = "Lab"
      Environment = "Dev" 
  }
}

# Create Vnet
resource "azurerm_virtual_network" "main" {
  name                = "vNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}
# Create Subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a public IP for the system to use
resource "azurerm_public_ip" "azPubIp" {
  name = "azPubIp1"
  resource_group_name = azurerm_resource_group.main.name
  location = azurerm_resource_group.main.location
  allocation_method = "Static"
}
# Create NIC for the VM
resource "azurerm_network_interface" "main" {
  name                = "Ubuntu-nic1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.azPubIp.id
    primary = true
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "LabUbuntuVM"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]
  primary_network_interface_id = azurerm_network_interface.main.id
  vm_size               = "Standard_E2s_v3"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "LabAnsibleUbuntuVM"
    admin_username = "shi"
    admin_password = "OneSHIisnumber1!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags     = {
      Owner = "KBormann, JIsley"
      Requestor = "KBormann"
      SP = "Lab"
      Environment = "Dev" 
  }
}

# Configure Auto-Shutdown for the AD Server for each night at 10pm CST.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "UbuntuShutdown" {
  virtual_machine_id = azurerm_virtual_machine.main.id
  location           = azurerm_resource_group.main.location
  enabled            = true
  daily_recurrence_time = "2100"
  timezone              = "Central Standard Time"

  notification_settings {
    enabled         = false
  }
}
