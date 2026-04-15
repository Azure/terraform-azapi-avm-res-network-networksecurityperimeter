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

# Storage Account to be protected by the NSP
resource "azurerm_storage_account" "this" {
  account_replication_type = "ZRS"
  account_tier             = "Standard"
  location                 = module.resourcegroup.resource.location
  name                     = module.naming.storage_account.name_unique
  resource_group_name      = module.resourcegroup.resource.name
  tags = {
    environment = "example"
  }
}

# Network Security Perimeter protecting the Storage Account
module "network_security_perimeter" {
  source = "../../"

  location            = module.resourcegroup.resource.location
  name                = module.naming.unique-seed
  resource_group_name = module.resourcegroup.resource.name
  # Inbound: allow a corporate IP range and the deployer's subscription
  # Outbound: allow the storage account to reach a specific FQDN
  access_rules = {
    allow_inbound_corp = {
      name             = "allow-inbound-corp"
      profile_key      = "blob_profile"
      direction        = "Inbound"
      address_prefixes = ["203.0.113.0/24"]
    }
    allow_inbound_subscription = {
      name        = "allow-inbound-subscription"
      profile_key = "blob_profile"
      direction   = "Inbound"
      subscriptions = [
        "/subscriptions/${data.azurerm_client_config.this.subscription_id}"
      ]
    }
    allow_outbound_fqdn = {
      name                         = "allow-outbound-fqdn"
      profile_key                  = "blob_profile"
      direction                    = "Outbound"
      fully_qualified_domain_names = ["login.microsoftonline.com"]
    }
  }
  enable_telemetry = var.enable_telemetry
  # Profiles: one for blob storage, one for general access
  profiles = {
    blob_profile = {
      name = "blob-storage-profile"
    }
  }
  # Associate the Storage Account with the NSP in Learning mode
  resource_associations = {
    storage = {
      name                     = "storage-association"
      profile_key              = "blob_profile"
      private_link_resource_id = azurerm_storage_account.this.id
      access_mode              = "Learning"
    }
  }
  tags = {
    environment = "example"
    scenario    = "storage-nsp-protection"
  }
}
