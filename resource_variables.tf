###################################################################################################
# VARIABLES
###################################################################################################

variable "azure_subscription_id" {}
variable "azure_client_id" {}
variable "azure_client_secret" {}
variable "azure_tenant_id" {}
variable "environment_tag" {}

variable "location" {
    description = "Location for components"
    default = "uksouth"
}





