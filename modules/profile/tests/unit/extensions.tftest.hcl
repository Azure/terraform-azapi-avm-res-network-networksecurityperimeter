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

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp/profiles/profile"
  }
}

variables {
  name             = "profile"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp"
  enable_telemetry = false
}

run "explicit_scope_body_identity_controls" {
  command = apply
  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        name                             = "00000000-0000-0000-0000-000000000010"
        principal_id                     = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name       = "rEaDeR"
        skip_service_principal_aad_check = true
        description                      = "Explicitly requested"
        condition                        = "test condition"
        condition_version                = "2.0"
      }
    }
    retry               = { error_message_regex = ["ScopeLocked"], interval_seconds = 3 }
    timeouts            = { create = "19m", delete = "8m" }
    resource_types      = { authorization_locks = "Microsoft.Authorization/locks@2016-09-01" }
    ignore_body_changes = { authorization_role_assignments = ["properties.description"] }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].parent_id == azapi_resource.this.id && azapi_resource.role_assignments["reader"].name == var.role_assignments.reader.name
    error_message = "Assignment scope and explicit GUID must be preserved."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.principalType == "ServicePrincipal" && azapi_resource.role_assignments["reader"].body.properties.conditionVersion == "2.0" && azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId == data.azapi_resource_list.role_definitions["child"].output.results[0].id
    error_message = "Canonical role input must map to the verified ARM body and case-insensitive role lookup."
  }
  assert {
    condition     = data.azapi_resource_list.role_definitions["child"].parent_id == azapi_resource.this.id && random_uuid.role_assignment_name["reader"].keepers.scope == lower("${var.parent_id}/profiles/${var.name}") && random_uuid.role_assignment_name["reader"].keepers.role_id == lower(var.role_assignments.reader.role_definition_id_or_name) && azapi_resource.role_assignments["reader"].replace_triggers_external_values.role_definition_id == lower(var.role_assignments.reader.role_definition_id_or_name) && azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId == data.azapi_resource_list.role_definitions["child"].output.results[0].id
    error_message = "Lookup must depend on the created profile; identity uses the configured selector while the body uses the resolved ID."
  }
  assert {
    condition     = azapi_resource.lock[0].name == "lock-CanNotDelete" && azapi_resource.lock[0].body.properties.level == "CanNotDelete" && azapi_resource.lock[0].retry.interval_seconds == 3 && azapi_resource.role_assignments["reader"].timeouts.delete == "8m" && azapi_resource.lock[0].type == var.resource_types.authorization_locks
    error_message = "Lock defaults/API and shared retry/timeouts must be effective."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "leaves_role_alias_conflicts_to_azure" {
  command = plan
  variables {
    role_assignments = {
      by_name = {
        principal_id               = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name = "reader"
      }
      by_id = {
        principal_id               = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "direct_owner_immutable_controls" {
  command = apply
  variables {
    role_assignments = {
      reader = {
        name                       = "00000000-0000-0000-0000-000000000010"
        principal_id               = "00000000-0000-0000-0000-000000000012"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
  }
  assert {
    condition     = length(azapi_resource.lock) == 0 && azapi_resource.role_assignments["reader"].parent_id == azapi_resource.this.id && azapi_resource.role_assignments["reader"].replace_triggers_external_values.principal_id == var.role_assignments.reader.principal_id && output.extension_resource_ids.lock == null
    error_message = "The direct owner must preserve immutable principal controls and leave optional locks absent."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "leaves_explicit_guid_conflicts_to_azure" {
  command = plan
  variables {
    role_assignments = {
      a = {
        name                       = "00000000-0000-0000-0000-000000000010"
        principal_id               = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
      b = {
        name                       = "00000000-0000-0000-0000-000000000010"
        principal_id               = "00000000-0000-0000-0000-000000000012"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "leaves_contextual_role_definition_aliases_to_azure" {
  command = plan
  variables {
    role_assignments = {
      a = {
        principal_id               = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
      b = {
        principal_id               = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000099/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      }
    }
  }
  providers = {
    azapi  = azapi
    random = random
  }
}
