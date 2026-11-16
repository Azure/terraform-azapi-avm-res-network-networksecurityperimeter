mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000001"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        }]
      }
    }
  }
}

mock_provider "random" {}

variables {
  name             = "nsp-test"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test"
  location         = "eastus2"
  enable_telemetry = false
}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-test"
  }
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.type == "Microsoft.Network/networkSecurityPerimeters@2025-05-01"
    error_message = "The perimeter must use the caller's existing scope and default API."
  }
  assert {
    condition     = length(output.profiles) == 0 && length(output.links) == 0 && length(output.link_references) == 0 && length(azapi_resource.lock) == 0 && length(azapi_resource.role_assignments) == 0
    error_message = "Optional surfaces must be absent by default."
  }
  assert {
    condition     = length(azapi_resource.telemetry) == 0 && output.resource.id == output.resource_id
    error_message = "Telemetry opt-out and stable resource identity outputs must work."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "children_and_interfaces" {
  command = apply

  variables {
    profiles = {
      primary = { name = "profile" }
    }
    access_rules = {
      inbound = {
        name             = "inbound"
        profile_key      = "primary"
        direction        = "Inbound"
        address_prefixes = ["203.0.113.0/24"]
      }
    }
    resource_associations = {
      storage = {
        name                     = "storage"
        profile_key              = "primary"
        private_link_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/example"
        access_mode              = "Enforced"
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        role_definition_id_or_name       = "rEaDeR"
        principal_id                     = "00000000-0000-0000-0000-000000000001"
        skip_service_principal_aad_check = true
        description                      = "mock reader"
      }
    }
    tags     = { environment = "test" }
    retry    = { error_message_regex = ["ScopeLocked"], interval_seconds = 3, max_interval_seconds = 10 }
    timeouts = { create = "20m", delete = "15m" }
  }

  override_resource {
    target = module.nsp_profile["primary"].azapi_resource.this
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-test/profiles/profile"
    }
  }

  assert {
    condition     = keys(output.profiles) == ["primary"] && keys(output.access_rules) == ["inbound"] && keys(output.resource_associations) == ["storage"]
    error_message = "The parent must retain arbitrary consumer keys when aggregating children."
  }
  assert {
    condition     = output.profiles["primary"].resource_id == "${output.resource_id}/profiles/profile"
    error_message = "Profile identity must be exposed through its scalar output."
  }
  assert {
    condition     = azapi_resource.lock[0].name == "lock-CanNotDelete" && azapi_resource.lock[0].body.properties.notes == "Cannot delete the resource or its child resources."
    error_message = "The released lock name and notes defaults must be retained."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.principalType == "ServicePrincipal" && endswith(azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId, "/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7") && azapi_resource.role_assignments["reader"].body.properties.description == "mock reader"
    error_message = "Case-insensitive role resolution, description and principalType translation must reach the ARM body."
  }
  assert {
    condition     = azapi_resource.this.tags.environment == "test" && azapi_resource.this.retry.interval_seconds == 3 && azapi_resource.lock[0].timeouts.delete == "15m"
    error_message = "Tags, retry and timeout interfaces must configure their resources."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "tenant_role_id_and_custom_lock" {
  command = apply
  variables {
    lock = { kind = "ReadOnly", name = "custom-lock", notes = "custom notes" }
    role_assignments = {
      explicit = {
        name                       = "11111111-1111-1111-1111-111111111111"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "00000000-0000-0000-0000-000000000001"
        principal_type             = "Group"
      }
    }
  }
  assert {
    condition     = azapi_resource.lock[0].body.properties.level == "ReadOnly" && azapi_resource.lock[0].body.properties.notes == "custom notes" && azapi_resource.lock[0].name == "custom-lock"
    error_message = "Custom lock notes/name and ReadOnly kind must be preserved."
  }
  assert {
    condition     = length(data.azapi_resource_list.role_definitions) == 0 && startswith(azapi_resource.role_assignments["explicit"].body.properties.roleDefinitionId, "/subscriptions/00000000-0000-0000-0000-000000000000/")
    error_message = "Tenant-level role definition IDs must be subscription-qualified without a role-name lookup."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "reject_unknown_profile" {
  command = plan
  variables {
    access_rules = {
      invalid = { name = "invalid", profile_key = "missing", direction = "Inbound" }
    }
  }
  expect_failures = [var.access_rules]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "telemetry_enabled" {
  command = apply
  variables {
    enable_telemetry = true
  }
  assert {
    condition     = length(azapi_resource.telemetry) == 1 && azapi_resource.telemetry[0].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000" && length(azapi_resource.telemetry[0].body.properties.template.resources) == 0
    error_message = "Enabled telemetry must use an empty subscription-scope deployment, not resource tags or a legacy telemetry resource."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "reject_duplicate_profile_identity" {
  command = plan
  variables {
    profiles = {
      a = { name = "duplicate" }
      b = { name = "DUPLICATE" }
    }
  }
  expect_failures = [var.profiles]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "reject_bad_scope" {
  command = plan
  variables {
    parent_id = "not-an-arm-id"
  }
  expect_failures = [var.parent_id]
  providers = {
    azapi  = azapi
    random = random
  }
}
