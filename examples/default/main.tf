data "azapi_client_config" "this" {}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-nsp-${random_string.suffix.result}"
  parent_id              = data.azapi_client_config.this.subscription_resource_id
  type                   = "Microsoft.Resources/resourceGroups@2024-03-01"
  body                   = {}
  response_export_values = []
}

module "network_security_perimeter" {
  source = "../../"

  location  = var.location
  name      = "nsp-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  access_rules = {
    allow_inbound_public = {
      name             = "allow-inbound-public"
      profile_key      = "profile1"
      direction        = "Inbound"
      address_prefixes = ["203.0.113.0/24", "198.51.100.0/24"]
      lock             = { kind = "CanNotDelete", name = "rule-lock" }
      role_assignments = {
        reader = {
          role_definition_id_or_name = "Reader"
          principal_id               = data.azapi_client_config.this.object_id
        }
      }
    }
    allow_outbound = {
      name                         = "allow-outbound"
      profile_key                  = "profile1"
      direction                    = "Outbound"
      fully_qualified_domain_names = ["example.com"]
    }
  }
  enable_telemetry = var.enable_telemetry
  lock             = { kind = "CanNotDelete" }
  profiles = {
    profile1 = {
      name = "default-profile"
      role_assignments = {
        reader = {
          role_definition_id_or_name = "Reader"
          principal_id               = data.azapi_client_config.this.object_id
        }
      }
    }
  }
  role_assignments = {
    reader = {
      role_definition_id_or_name = "Reader"
      principal_id               = data.azapi_client_config.this.object_id
    }
  }
  tags = {
    environment = "example"
  }
}
