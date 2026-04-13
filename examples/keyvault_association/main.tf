terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.21"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

## Section to provide a random Azure region for the resource group
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.12.0"

  geography_group_filter = "US"
  region_name_regex      = "^(eastus|eastus2|westus|westus2|westus3|centralus|northcentralus|southcentralus|westcentralus)$"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

data "azurerm_client_config" "this" {}

# Resource group for all resources
module "resourcegroup" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.2.2"

  location         = module.regions.regions[random_integer.region_index.result].name
  name             = module.naming.resource_group.name_unique
  enable_telemetry = var.enable_telemetry
}

# Key Vault to be protected by the NSP
module "keyvault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.2"

  location            = module.resourcegroup.resource.location
  name                = module.naming.key_vault.name_unique
  resource_group_name = module.resourcegroup.resource.name
  tenant_id           = data.azurerm_client_config.this.tenant_id
  enable_telemetry    = var.enable_telemetry
  tags = {
    environment = "example"
  }
}

# Network Security Perimeter protecting the Key Vault
module "network_security_perimeter" {
  source = "../../"

  location            = module.resourcegroup.resource.location
  name                = module.naming.unique-seed
  resource_group_name = module.resourcegroup.resource.name
  # Inbound: allow access from a known public IP range (e.g., corporate egress)
  # Outbound: allow the Key Vault to reach a specific FQDN
  access_rules = {
    allow_inbound_corp_egress = {
      name             = "allow-inbound-corp-egress"
      profile_key      = "keyvault_profile"
      direction        = "Inbound"
      address_prefixes = ["203.0.113.0/24"]
    }
    allow_inbound_subscription = {
      name        = "allow-inbound-subscription"
      profile_key = "keyvault_profile"
      direction   = "Inbound"
      subscriptions = [
        "/subscriptions/${data.azurerm_client_config.this.subscription_id}"
      ]
    }
  }
  enable_telemetry = var.enable_telemetry
  # Create a profile for the Key Vault workload
  profiles = {
    keyvault_profile = {
      name = "keyvault-profile"
    }
  }
  # Associate the Key Vault with the NSP profile
  resource_associations = {
    keyvault = {
      name                     = "keyvault-association"
      profile_key              = "keyvault_profile"
      private_link_resource_id = module.keyvault.resource_id
      access_mode              = "Learning"
    }
  }
  tags = {
    environment = "example"
    scenario    = "keyvault-nsp-protection"
  }
}
