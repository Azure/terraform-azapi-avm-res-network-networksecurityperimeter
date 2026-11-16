mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

variables {
  name             = "profile"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp"
  enable_telemetry = false
}

# SFR4: telemetry-only location stays nullable on opt-out, not unconditionally required.
run "telemetry_disabled_null_location" {
  command = plan
  variables {
    location = null
  }
  assert {
    condition     = var.location == null && length(azapi_resource.telemetry) == 0 && length(terraform_data.telemetry) == 0 && length(data.azapi_client_config.telemetry) == 0
    error_message = "Explicit null must be accepted without telemetry resources or telemetry client lookup when opted out."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "telemetry_enabled_requires_location" {
  command = plan
  variables {
    enable_telemetry = true
  }
  expect_failures = [var.location]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "telemetry_enabled_uses_location" {
  command = apply
  variables {
    enable_telemetry = true
    location         = "eastus2"
  }
  assert {
    condition     = length(azapi_resource.telemetry) == 1 && azapi_resource.telemetry[0].location == var.location && azapi_resource.telemetry[0].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "Enabled telemetry must deploy at the active subscription in the caller's region."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "single_profile_controls" {
  command = apply
  variables {
    resource_types = { network_network_security_perimeters_profiles = "Microsoft.Network/networkSecurityPerimeters/profiles@2024-07-01" }
    retry          = { error_message_regex = ["ScopeLocked"], interval_seconds = 4 }
    timeouts       = { create = "21m" }
    ignore_body_changes = {
      network_network_security_perimeters_profiles = ["properties"]
    }
  }
  assert {
    condition     = azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.type == var.resource_types.network_network_security_perimeters_profiles && azapi_resource.this.retry.interval_seconds == 4 && azapi_resource.this.timeouts.create == "21m"
    error_message = "Standalone profile scope/API/retry/timeouts must be configurable."
  }
  assert {
    condition     = length(keys(azapi_resource.this.body.properties)) == 0 && output.resource.id == output.resource_id && length(azapi_resource.telemetry) == 0
    error_message = "The profile body must not replay server-owned properties and telemetry must be optional."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "reject_bad_parent" {
  command = plan
  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test"
  }
  expect_failures = [var.parent_id]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "standalone_profile_extensions" {
  command = apply
  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        name                       = "00000000-0000-0000-0000-000000000010"
        principal_id               = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
  }
  assert {
    condition     = output.extension_resource_ids.lock == "${var.parent_id}/profiles/${var.name}/providers/Microsoft.Authorization/locks/lock-CanNotDelete" && length(output.extension_resource_ids.role_assignments) == 1
    error_message = "A standalone profile must own its optional lock and explicitly requested RBAC."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}
