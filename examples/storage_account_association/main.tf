data "azapi_client_config" "this" {}

resource "random_string" "suffix" {
  length  = 12
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-nsp-storage-${random_string.suffix.result}"
  parent_id              = data.azapi_client_config.this.subscription_resource_id
  type                   = "Microsoft.Resources/resourceGroups@2024-03-01"
  body                   = {}
  response_export_values = []
}

resource "azapi_resource" "storage_account" {
  location  = var.location
  name      = "st${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Storage/storageAccounts@2025-01-01"
  body = {
    kind = "StorageV2"
    sku  = { name = "Standard_ZRS" }
    properties = {
      accessTier                   = "Hot"
      allowBlobPublicAccess        = false
      allowSharedKeyAccess         = false
      defaultToOAuthAuthentication = true
      minimumTlsVersion            = "TLS1_2"
      publicNetworkAccess          = "Disabled"
      supportsHttpsTrafficOnly     = true
      networkAcls = {
        bypass        = "None"
        defaultAction = "Deny"
      }
    }
  }
  response_export_values = []
}

module "network_security_perimeter" {
  source = "../../"

  location  = var.location
  name      = "nsp-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  access_rules = {
    allow_inbound_corp = {
      name             = "allow-inbound-corp"
      profile_key      = "blob_profile"
      direction        = "Inbound"
      address_prefixes = ["203.0.113.0/24"]
    }
    allow_inbound_subscription = {
      name          = "allow-inbound-subscription"
      profile_key   = "blob_profile"
      direction     = "Inbound"
      subscriptions = [data.azapi_client_config.this.subscription_resource_id]
    }
    allow_outbound_fqdn = {
      name                         = "allow-outbound-fqdn"
      profile_key                  = "blob_profile"
      direction                    = "Outbound"
      fully_qualified_domain_names = ["login.microsoftonline.com"]
    }
  }
  enable_telemetry = var.enable_telemetry
  lock             = { kind = "CanNotDelete" }
  profiles = {
    blob_profile = { name = "blob-storage-profile" }
  }
  resource_associations = {
    storage = {
      name                     = "storage-association"
      profile_key              = "blob_profile"
      private_link_resource_id = azapi_resource.storage_account.id
      access_mode              = "Learning"
      lock                     = { kind = "CanNotDelete", name = "association-lock" }
      private_link_resource_extensions = {
        lock_inheritance_enabled = false
        role_assignments = {
          reader = {
            role_definition_id_or_name = "Reader"
            principal_id               = data.azapi_client_config.this.object_id
          }
        }
      }
    }
  }
  tags = {
    environment = "example"
    scenario    = "storage-nsp-protection"
  }
}
