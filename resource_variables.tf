###################################################################################################
# VARIABLES
###################################################################################################

variable "azure_subscription_id" {}
variable "azure_client_id" {}
variable "azure_client_secret" {}
variable "azure_tenant_id" {}
variable "environment" {}
variable "instance_count" {
    description = "Count of Virtual Machines to be created"
}
variable "location" {
    description = "Location for components"
    default = "uksouth"
}
variable "resource_group_name" {
    description = "Name of the resource group to be created"
    default = "XYZ"
}






