# AzAPI is mocked; random is intentionally real so UUIDs use the pinned provider.
mock_provider "azapi" {
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000010"
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

provider "random" {}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-review"
  }
}

variables {
  name             = "nsp-review"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test"
  location         = "eastus2"
  enable_telemetry = false
  role_assignments = {
    generated = {
      principal_id               = "00000000-0000-0000-0000-000000000001"
      role_definition_id_or_name = "rg custom reader"
    }
  }
}

run "generated_identity_lookup_and_default_retries" {
  command = apply

  assert {
    condition     = azapi_resource.role_assignments["generated"].name == random_uuid.role_assignment_name["generated"].result && can(regex("^[0-9a-f-]{36}$", random_uuid.role_assignment_name["generated"].result))
    error_message = "Omitted names must use the identity-keyed real random UUID."
  }
  assert {
    condition     = random_uuid.role_assignment_name["generated"].keepers.scope == lower(local.perimeter_resource_id) && random_uuid.role_assignment_name["generated"].keepers.principal_id == var.role_assignments.generated.principal_id && random_uuid.role_assignment_name["generated"].keepers.role_id == lower(var.role_assignments.generated.role_definition_id_or_name) && azapi_resource.role_assignments["generated"].replace_triggers_external_values.role_definition_id == lower(var.role_assignments.generated.role_definition_id_or_name) && azapi_resource.role_assignments["generated"].body.properties.roleDefinitionId == data.azapi_resource_list.role_definitions[0].output.results[0].id
    error_message = "All three immutable assignment identities must participate in UUID rotation."
  }
  assert {
    condition     = data.azapi_resource_list.role_definitions[0].parent_id == azapi_resource.this.id
    error_message = "Primary role lookup must depend on the created NSP scope, retaining inherited RG-scoped custom roles."
  }
  assert {
    condition     = azapi_resource.role_assignments["generated"].retry.error_message_regex == tolist(["ScopeLocked", "PrincipalNotFound", "LinkedAuthorizationFailed"])
    error_message = "RBAC lock-propagation and principal/delegated replication errors must be retryable by default."
  }
}

run "case_only_selector_preserves_uuid" {
  command = apply
  variables {
    role_assignments = {
      generated = {
        principal_id               = "00000000-0000-0000-0000-000000000001"
        role_definition_id_or_name = "RG CUSTOM READER"
      }
    }
  }
  assert {
    condition     = random_uuid.role_assignment_name["generated"].keepers.role_id == "rg custom reader" && azapi_resource.role_assignments["generated"].replace_triggers_external_values.role_definition_id == "rg custom reader"
    error_message = "Changing only selector casing must retain normalized UUID keeper and replacement role components."
  }
}

run "configured_role_change_rotates_uuid" {
  command = apply
  variables {
    role_assignments = {
      generated = {
        principal_id               = "00000000-0000-0000-0000-000000000001"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000030"
      }
    }
  }
  assert {
    condition     = random_uuid.role_assignment_name["generated"].keepers.role_id == lower(var.role_assignments.generated.role_definition_id_or_name) && azapi_resource.role_assignments["generated"].replace_triggers_external_values.role_definition_id == lower(var.role_assignments.generated.role_definition_id_or_name)
    error_message = "A configured role change must reach both identity components independently of role lookup; real-provider plans test replacement."
  }
}

run "explicit_guid_and_retry_override" {
  command = apply
  variables {
    role_assignments = {
      explicit = {
        name                       = "00000000-0000-0000-0000-000000000020"
        principal_id               = "00000000-0000-0000-0000-000000000001"
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000010"
      }
    }
    retry = { error_message_regex = ["OnlyThisError"], interval_seconds = 2, max_interval_seconds = 4 }
  }
  assert {
    condition     = azapi_resource.role_assignments["explicit"].name == var.role_assignments.explicit.name && azapi_resource.role_assignments["explicit"].retry.error_message_regex == tolist(["OnlyThisError"]) && azapi_resource.role_assignments["explicit"].retry.interval_seconds == 2
    error_message = "Explicit GUIDs and consumer retry overrides must win over generated defaults."
  }
}

run "retry_null_uses_provider_defaults" {
  command = apply
  variables {
    retry = null
  }
  assert {
    condition     = azapi_resource.role_assignments["generated"].retry == null
    error_message = "Explicit retry null must remain an opt-out from module defaults."
  }
}
