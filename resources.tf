# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "${var.azure_subscription_id}"
    client_id       = "${var.azure_client_id}"
    client_secret   = "${var.azure_client_secret}"
    tenant_id       = "${var.azure_tenant_id}"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "resourcegroup" {
    name     = "${var.resource_group_name}"
    location = "${var.location}"

    tags {
        environment = "${var.environment}"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "virtualnetwork" {
    name                = "${var.resource_group_name}_${var.environment}_vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "${azurerm_resource_group.resourcegroup.location}"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"

    tags {
        environment = "${var.environment}"
    }
}

# Create subnet
resource "azurerm_subnet" "subnet" {
    name                 = "${var.resource_group_name}_${var.environment}_subnet"
    resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"
    virtual_network_name = "${azurerm_virtual_network.virtualnetwork.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "publicip" {
    count                        = "${var.instance_count}"
    name                         = "${var.resource_group_name}_${var.environment}_public_ip_${count.index + 1}"
    location                     = "${azurerm_resource_group.resourcegroup.location}"
    resource_group_name          = "${azurerm_resource_group.resourcegroup.name}"
    allocation_method            = "Dynamic"

    tags {
        environment = "${var.environment}"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "networkscecuritygroup" {
    name                = "${var.resource_group_name}_${var.environment}_security_group"
    location            = "${azurerm_resource_group.resourcegroup.location}"
    resource_group_name = "${azurerm_resource_group.resourcegroup.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "${var.environment}"
    }
}

# Create network interface
resource "azurerm_network_interface" "networkinterface" {
    count                     = "${var.instance_count}"
    name                      = "${var.resource_group_name}_${var.environment}_network_interface_${count.index + 1}"
    location                  = "${azurerm_resource_group.resourcegroup.location}"
    resource_group_name       = "${azurerm_resource_group.resourcegroup.name}"
    network_security_group_id = "${azurerm_network_security_group.networkscecuritygroup.id}"

    ip_configuration {
        name                          = "${var.resource_group_name}_${var.environment}_network_interface_configuration"
        subnet_id                     = "${azurerm_subnet.subnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${element(azurerm_public_ip.publicip.*.id, count.index)}"
    }

    tags {
        environment = "${var.environment}"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.resourcegroup.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.resourcegroup.name}"
    location                    = "${azurerm_resource_group.resourcegroup.location}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "${var.environment}"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "vm" {
    count                 = "${var.instance_count}"
    name                  = "${var.resource_group_name}_${var.environment}_vm_${count.index + 1}"
    location              = "${azurerm_resource_group.resourcegroup.location}"
    resource_group_name   = "${azurerm_resource_group.resourcegroup.name}"
    network_interface_ids = ["${element(azurerm_network_interface.networkinterface.*.id, count.index)}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "${var.resource_group_name}_${var.environment}_os_disk_${count.index + 1}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }


    os_profile {
        computer_name  = "myvm"
        admin_username = "azureuser"
        admin_password = "Password1234!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    #    ssh_keys {
    #        path     = "/home/azureuser/.ssh/authorized_keys"
    #        key_data = "ssh-rsa AAAAB3Nz{snip}hwhqT9h"
    #    }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.storageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "${var.environment}"
    }        
}

resource "azurerm_virtual_machine_extension" "vmextension" {
  count                = "${var.instance_count}"
  name                 = "${var.resource_group_name}_${var.environment}_vmextension_mongodb"
  location             = "${azurerm_resource_group.resourcegroup.location}"
  resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"
  virtual_machine_name = "${element(azurerm_virtual_machine.vm.*.name, count.index)}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  depends_on           = ["azurerm_virtual_machine.vm"]

  # CustomVMExtension Documetnation: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows

  settings = <<SETTINGS
    {
        "fileUris":["https://csbd36c792c0620x46e2xb50.blob.core.windows.net/public-files/post_deploy_install_mongo.sh"],
        "commandToExecute": "bash post_deploy_install_mongo.sh"
    }
SETTINGS
}