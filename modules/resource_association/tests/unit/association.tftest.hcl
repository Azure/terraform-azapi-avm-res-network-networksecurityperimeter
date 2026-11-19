mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
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
  name                     = "association"
  parent_id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp"
  profile_resource_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp/profiles/profile"
  private_link_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.KeyVault/vaults/example"
  enable_telemetry         = false
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

run "external_resource_reference" {
  command = apply
  variables {
    access_mode = "Enforced"
    retry       = { error_message_regex = ["ScopeLocked"], interval_seconds = 6 }
    timeouts    = { delete = "12m" }
  }
  assert {
    condition     = azapi_resource.this.body.properties.accessMode == "Enforced" && azapi_resource.this.body.properties.privateLinkResource.id == var.private_link_resource_id && azapi_resource.this.body.properties.profile.id == var.profile_resource_id
    error_message = "The association must reference (not own) external PaaS and profile resources."
  }
  assert {
    condition     = azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.retry.interval_seconds == 6 && azapi_resource.this.timeouts.delete == "12m" && output.resource.id == output.resource_id
    error_message = "Perimeter scope, controls and stable identity output must work standalone."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "retarget_body_and_known_extension_scopes" {
  command = plan
  variables {
    private_link_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/targetb"
    lock                     = { kind = "CanNotDelete", name = "association-lock" }
    role_assignments = {
      reader = {
        name                       = "00000000-0000-0000-0000-000000000031"
        principal_id               = "00000000-0000-0000-0000-000000000032"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
    private_link_resource_extensions = { lock_inheritance_enabled = false }
  }
  assert {
    condition     = azapi_resource.this.body.properties.privateLinkResource.id == var.private_link_resource_id && azapi_resource.role_assignments["reader"].parent_id == "${var.parent_id}/resourceAssociations/${var.name}" && output.extension_resource_ids.lock == "${var.parent_id}/resourceAssociations/${var.name}/providers/Microsoft.Authorization/locks/association-lock"
    error_message = "Retargeting must keep the association extension scope known at plan time without transferring target lifecycle ownership."
  }
  assert {
    condition     = length(azapi_resource.target_lock) == 0 && length(azapi_resource.target_role_assignments) == 0 && azapi_resource.role_assignments["reader"].name == var.role_assignments.reader.name
    error_message = "Opted-out external extensions must remain unowned, and the explicit association Reader GUID must be preserved."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "mutable_profile_and_mode_body" {
  command = apply
  variables {
    private_link_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/targetb"
    profile_resource_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp/profiles/other"
    access_mode              = "Enforced"
  }
  assert {
    condition     = azapi_resource.this.body.properties.profile.id == var.profile_resource_id && azapi_resource.this.body.properties.accessMode == "Enforced" && azapi_resource.this.body.properties.privateLinkResource.id == var.private_link_resource_id
    error_message = "Mutable profile and access mode must map independently from the constant external target."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "reject_bad_mode" {
  command = plan
  variables {
    access_mode = "Invalid"
  }
  expect_failures = [var.access_mode]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "standalone_target_inheritance_and_explicit_rbac" {
  command = apply
  variables {
    lock = { kind = "CanNotDelete", name = "association-lock" }
    private_link_resource_extensions = {
      role_assignments = {
        reader = {
          name                       = "00000000-0000-0000-0000-000000000010"
          principal_id               = "00000000-0000-0000-0000-000000000011"
          role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }
      }
    }
  }
  assert {
    condition     = output.extension_resource_ids.private_link_resource.lock == "${var.private_link_resource_id}/providers/Microsoft.Authorization/locks/association-lock" && length(output.extension_resource_ids.private_link_resource.role_assignments) == 1
    error_message = "Standalone association target extensions must inherit its lock and use explicit RBAC without owning the PaaS target."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "standalone_target_lock_optout" {
  command = apply
  variables {
    lock                             = { kind = "CanNotDelete" }
    private_link_resource_extensions = { lock_inheritance_enabled = false }
  }
  assert {
    condition     = output.extension_resource_ids.lock != null && output.extension_resource_ids.private_link_resource.lock == null && length(output.extension_resource_ids.private_link_resource.role_assignments) == 0
    error_message = "Target lock opt-out must not disable the association's own lock or create automatic permissions."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "normalized_target_direct_controls_and_body" {
  command = apply
  variables {
    private_link_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/external/"
    lock                     = { kind = "CanNotDelete", notes = "Own child" }
    role_assignments = {
      child = {
        name                       = "00000000-0000-0000-0000-000000000020"
        principal_id               = "00000000-0000-0000-0000-000000000021"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
    private_link_resource_extensions = {
      lock = { kind = "ReadOnly", name = "target-lock", notes = "External target" }
      role_assignments = {
        reader = {
          name                             = "00000000-0000-0000-0000-000000000022"
          principal_id                     = "00000000-0000-0000-0000-000000000023"
          role_definition_id_or_name       = "rEaDeR"
          skip_service_principal_aad_check = true
          condition                        = "test condition"
          condition_version                = "2.0"
          description                      = "Explicit target permission"
        }
      }
    }
    resource_types = {
      authorization_locks            = "Microsoft.Authorization/locks@2016-09-01"
      authorization_role_assignments = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
      authorization_role_definitions = "Microsoft.Authorization/roleDefinitions@2018-01-01-preview"
    }
    ignore_body_changes = {
      authorization_locks            = ["properties.notes"]
      authorization_role_assignments = ["properties.description"]
    }
    retry    = { error_message_regex = ["ScopeLocked"], interval_seconds = 3, max_interval_seconds = 9 }
    timeouts = { create = "19m", read = "2m", update = "7m", delete = "8m" }
  }
  assert {
    condition     = azapi_resource.lock[0].parent_id == "${var.parent_id}/resourceAssociations/${var.name}" && azapi_resource.target_lock[0].parent_id == trimsuffix(var.private_link_resource_id, "/") && azapi_resource.target_role_assignments["reader"].parent_id == trimsuffix(var.private_link_resource_id, "/")
    error_message = "Child and target must remain distinct graph nodes; target writes must use the normalized external scope."
  }
  assert {
    condition     = azapi_resource.role_assignments["child"].type == var.resource_types.authorization_role_assignments && azapi_resource.target_role_assignments["reader"].type == var.resource_types.authorization_role_assignments && azapi_resource.lock[0].type == var.resource_types.authorization_locks && azapi_resource.target_lock[0].type == var.resource_types.authorization_locks && data.azapi_resource_list.role_definitions["target"].type == var.resource_types.authorization_role_definitions
    error_message = "One direct ARM-kind control must configure both separately owned scope resources and the stable role lookup."
  }
  assert {
    condition     = azapi_resource.target_lock[0].body.properties.notes == "External target" && azapi_resource.target_lock[0].body.properties.level == "ReadOnly" && azapi_resource.lock[0].body.properties.level == "CanNotDelete" && azapi_resource.target_role_assignments["reader"].name == var.private_link_resource_extensions.role_assignments.reader.name && azapi_resource.target_role_assignments["reader"].body.properties.principalType == "ServicePrincipal" && azapi_resource.target_role_assignments["reader"].body.properties.conditionVersion == "2.0"
    error_message = "Direct declarations must preserve canonical bodies, per-target lock override and explicit assignment GUID."
  }
  assert {
    condition     = azapi_resource.target_role_assignments["reader"].body.properties.roleDefinitionId == data.azapi_resource_list.role_definitions["target"].output.results[0].id && data.azapi_resource_list.role_definitions["target"].parent_id == trimsuffix(var.private_link_resource_id, "/") && azapi_resource.target_role_assignments["reader"].replace_triggers_external_values.principal_id == var.private_link_resource_extensions.role_assignments.reader.principal_id && azapi_resource.target_role_assignments["reader"].replace_triggers_external_values.description == "Explicit target permission"
    error_message = "Stable case-insensitive role lookup and immutable assignment triggers must survive wrapper removal."
  }
  assert {
    condition     = random_uuid.target_role_assignment_name["reader"].keepers.scope == lower(trimsuffix(var.private_link_resource_id, "/")) && random_uuid.target_role_assignment_name["reader"].keepers.principal_id == var.private_link_resource_extensions.role_assignments.reader.principal_id && random_uuid.target_role_assignment_name["reader"].keepers.role_id == lower(azapi_resource.target_role_assignments["reader"].body.properties.roleDefinitionId) && random_uuid.role_assignment_name["child"].keepers.scope == lower("${var.parent_id}/resourceAssociations/${var.name}")
    error_message = "Association child and target UUID keepers must use their separate assignment scopes, including target retargeting."
  }
  assert {
    condition = alltrue([
      for resource in [azapi_resource.lock[0], azapi_resource.target_lock[0], azapi_resource.role_assignments["child"], azapi_resource.target_role_assignments["reader"]] :
      resource.retry.error_message_regex == var.retry.error_message_regex && resource.retry.interval_seconds == var.retry.interval_seconds && resource.retry.max_interval_seconds == var.retry.max_interval_seconds && resource.timeouts.create == var.timeouts.create && resource.timeouts.read == var.timeouts.read && resource.timeouts.update == var.timeouts.update && resource.timeouts.delete == var.timeouts.delete
    ])
    error_message = "Retry/timeouts must cascade unchanged to every direct extension resource."
  }
  assert {
    condition     = !strcontains(output.extension_resource_ids.private_link_resource.lock, "//providers/") && output.extension_resource_ids.private_link_resource.lock == "${trimsuffix(var.private_link_resource_id, "/")}/providers/Microsoft.Authorization/locks/target-lock"
    error_message = "Input-derived extension IDs must not introduce malformed or duplicate target identities."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "reject_child_target_explicit_guid_reuse" {
  command = plan
  variables {
    role_assignments = {
      child = {
        name                       = "00000000-0000-0000-0000-000000000010"
        principal_id               = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
    private_link_resource_extensions = {
      role_assignments = {
        target = {
          name                       = "00000000-0000-0000-0000-000000000010"
          principal_id               = "00000000-0000-0000-0000-000000000012"
          role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }
      }
    }
  }
  expect_failures = [terraform_data.extension_ownership]
  providers = {
    azapi  = azapi
    random = random
  }
}
