run "null_target_with_child_lock_only" {
  command = plan
  variables {
    lock                        = { kind = "CanNotDelete" }
    remote_perimeter_extensions = { lock_inheritance_enabled = false }
  }
  assert {
    condition     = length(azapi_resource.lock) == 1 && length(azapi_resource.target_lock) == 0 && length(azapi_resource.target_role_assignments) == 0 && length(data.azapi_resource_list.role_definitions) == 0
    error_message = "A child-only lock must not require a remote ID or create remote extensions."
  }
}

run "reject_self_target" {
  command = plan
  variables {
    auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp"
  }
  expect_failures = [terraform_data.remote_scope]
}

run "reject_remote_lock_without_id" {
  command = plan
  variables {
    lock = { kind = "CanNotDelete" }
  }
  expect_failures = [terraform_data.remote_scope]
}

mock_provider "azapi" {
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "RG Custom Reader"
        }]
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

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp/links/link"
  }
}

variables {
  name             = "link"
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

run "remote_identity_and_lists" {
  command = apply
  variables {
    auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
    local_inbound_profiles                     = ["local"]
    remote_inbound_profiles                    = ["remote-a", "remote-b"]
    description                                = "test request"
    retry                                      = { error_message_regex = ["ScopeLocked"], interval_seconds = 7 }
    timeouts                                   = { update = "18m" }
  }
  assert {
    condition     = azapi_resource.this.body.properties.autoApprovedRemotePerimeterResourceId == var.auto_approved_remote_perimeter_resource_id && azapi_resource.this.body.properties.localInboundProfiles[0] == "local" && azapi_resource.this.body.properties.remoteInboundProfiles[1] == "remote-b"
    error_message = "Link body must retain create-only remote identity and local/remote list casing."
  }
  assert {
    condition     = contains(azapi_resource.this.replace_triggers_refs, "properties.autoApprovedRemotePerimeterResourceId") && azapi_resource.this.retry.interval_seconds == 7 && azapi_resource.this.timeouts.update == "18m"
    error_message = "Create-only remote retargeting must trigger replacement and expose controls."
  }
  assert {
    condition     = azapi_resource.this.body.properties.description == var.description
    error_message = "An explicitly supplied link description must be preserved."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.auto_approved_remote_perimeter_resource_id == var.auto_approved_remote_perimeter_resource_id
    error_message = "Immutable remote identity must also drive replacement independently of fully known body properties."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "null_and_empty_defaults" {
  command = apply
  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties), "description")
    error_message = "A null link description must be omitted from the request body, not serialized as null."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.auto_approved_remote_perimeter_resource_id == null
    error_message = "Manual-link null identity must remain wrapped so later remote identity changes are tracked."
  }
  assert {
    condition     = azapi_resource.this.body.properties.autoApprovedRemotePerimeterResourceId == null && length(azapi_resource.this.body.properties.localInboundProfiles) == 0 && length(azapi_resource.this.body.properties.remoteInboundProfiles) == 0
    error_message = "Link optional identity and lists must preserve null/empty defaults."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "standalone_link_remote_extensions" {
  command = apply
  variables {
    auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
    lock                                       = { kind = "CanNotDelete" }
    remote_perimeter_extensions = {
      lock = { kind = "ReadOnly", name = "remote-override" }
      role_assignments = {
        reader = {
          name                       = "00000000-0000-0000-0000-000000000010"
          principal_id               = "00000000-0000-0000-0000-000000000011"
          role_definition_id_or_name = "rg custom reader"
        }
      }
    }
  }
  assert {
    condition     = output.extension_resource_ids.remote_perimeter.lock == "${var.auto_approved_remote_perimeter_resource_id}/providers/Microsoft.Authorization/locks/remote-override" && length(output.extension_resource_ids.remote_perimeter.role_assignments) == 1 && output.extension_resource_ids.lock != null
    error_message = "The standalone link must own its extensions and honor remote overrides without owning the remote perimeter."
  }
  assert {
    condition     = data.azapi_resource_list.role_definitions["target"].parent_id == var.auto_approved_remote_perimeter_resource_id && random_uuid.target_role_assignment_name["reader"].keepers.scope == lower(var.auto_approved_remote_perimeter_resource_id) && random_uuid.target_role_assignment_name["reader"].keepers.principal_id == var.remote_perimeter_extensions.role_assignments.reader.principal_id && random_uuid.target_role_assignment_name["reader"].keepers.role_id == lower(azapi_resource.target_role_assignments["reader"].body.properties.roleDefinitionId) && contains(azapi_resource.target_role_assignments["reader"].retry.error_message_regex, "PrincipalNotFound")
    error_message = "Remote lookup must retain target-scoped custom roles; UUIDs must track target identity and RBAC defaults must apply."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}
