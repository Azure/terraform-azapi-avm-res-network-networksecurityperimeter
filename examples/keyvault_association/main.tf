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
  name                   = "rg-nsp-kv-${random_string.suffix.result}"
  parent_id              = data.azapi_client_config.this.subscription_resource_id
  type                   = "Microsoft.Resources/resourceGroups@2024-03-01"
  body                   = {}
  response_export_values = []
}

resource "azapi_resource" "key_vault" {
  location  = var.location
  name      = "kv${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.KeyVault/vaults@2024-11-01"
  body = {
    properties = {
      tenantId                  = data.azapi_client_config.this.tenant_id
      sku                       = { family = "A", name = "standard" }
      enableRbacAuthorization   = true
      enableSoftDelete          = true
      enablePurgeProtection     = true
      softDeleteRetentionInDays = 7
      publicNetworkAccess       = "Disabled"
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
    allow_inbound_corp_egress = {
      name             = "allow-inbound-corp-egress"
      profile_key      = "keyvault_profile"
      direction        = "Inbound"
      address_prefixes = ["203.0.113.0/24"]
    }
    allow_inbound_subscription = {
      name          = "allow-inbound-subscription"
      profile_key   = "keyvault_profile"
      direction     = "Inbound"
      subscriptions = [data.azapi_client_config.this.subscription_resource_id]
    }
  }
  enable_telemetry = var.enable_telemetry
  lock             = { kind = "CanNotDelete", name = "perimeter-and-target-lock" }
  profiles = {
    keyvault_profile = { name = "keyvault-profile" }
  }
  resource_associations = {
    keyvault = {
      name                     = "keyvault-association"
      profile_key              = "keyvault_profile"
      private_link_resource_id = azapi_resource.key_vault.id
      access_mode              = "Learning"
      private_link_resource_extensions = {
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
    scenario    = "keyvault-nsp-protection"
  }
}
