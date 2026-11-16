mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp/linkReferences/reference"
      output = {
        properties = {
          status                    = "Approved"
          remotePerimeterResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
        }
      }
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

variables {
  name             = "reference"
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

run "lookup_only" {
  command = apply
  assert {
    condition     = data.azapi_resource.this.parent_id == var.parent_id && output.resource.properties.status == "Approved" && output.resource_id == output.resource.id
    error_message = "Lookup must return observed properties and the existing identity."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "lookup_with_extensions" {
  command = apply
  variables {
    remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
    lock                         = { kind = "CanNotDelete" }
    retry                        = { error_message_regex = ["ScopeLocked"], interval_seconds = 5 }
    timeouts                     = { delete = "9m" }
    ignore_body_changes          = { authorization_locks = ["properties.notes"] }
    role_assignments = {
      reader = {
        name                       = "00000000-0000-0000-0000-000000000010"
        principal_id               = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
  }
  assert {
    condition     = data.azapi_resource.this.type == var.resource_types.network_network_security_perimeters_link_references && output.extension_resource_ids.lock == "${var.parent_id}/linkReferences/${var.name}/providers/Microsoft.Authorization/locks/lock-CanNotDelete" && output.extension_resource_ids.remote_perimeter.lock == "${var.remote_perimeter_resource_id}/providers/Microsoft.Authorization/locks/lock-CanNotDelete"
    error_message = "Adding reference/remote extensions must preserve GET-only reference lifecycle and input-derived scopes."
  }
  assert {
    condition     = azapi_resource.lock[0].type == "Microsoft.Authorization/locks@2020-05-01" && azapi_resource.target_lock[0].type == azapi_resource.lock[0].type && azapi_resource.role_assignments["reader"].type == "Microsoft.Authorization/roleAssignments@2022-04-01" && azapi_resource.target_lock[0].retry.interval_seconds == 5 && azapi_resource.role_assignments["reader"].timeouts.delete == "9m"
    error_message = "The GET-only owner must itself provide tested extension API defaults and cascade resource controls to distinct extension nodes."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "reject_lookup_remote_mismatch" {
  command = plan
  variables {
    remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/wrong"
  }
  expect_failures = [terraform_data.remote_scope]
  providers = {
    azapi  = azapi
    random = random
  }
}
