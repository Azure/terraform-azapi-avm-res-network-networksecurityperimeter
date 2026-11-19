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

variables {
  name             = "rule"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp/profiles/profile"
  direction        = "Inbound"
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

run "nested_subscription_shape" {
  command = apply
  variables {
    address_prefixes = ["203.0.113.0/24"]
    subscriptions    = ["/subscriptions/00000000-0000-0000-0000-000000000002"]
    retry            = { error_message_regex = ["ScopeLocked"], interval_seconds = 5 }
    timeouts         = { read = "4m" }
  }
  assert {
    condition     = azapi_resource.this.body.properties.direction == "Inbound" && azapi_resource.this.body.properties.addressPrefixes[0] == "203.0.113.0/24" && azapi_resource.this.body.properties.subscriptions[0].id == var.subscriptions[0]
    error_message = "ARM casing and subscription object-list shape must match the pinned API."
  }
  assert {
    condition     = length(azapi_resource.this.body.properties.fullyQualifiedDomainNames) == 0 && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.retry.interval_seconds == 5 && azapi_resource.this.timeouts.read == "4m"
    error_message = "Empty lists, profile scope and controls must be retained."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "outbound_and_final_clear_shape" {
  command = apply
  variables {
    direction                    = "Outbound"
    fully_qualified_domain_names = ["example.com"]
  }
  assert {
    condition     = azapi_resource.this.body.properties.fullyQualifiedDomainNames[0] == "example.com" && length(azapi_resource.this.body.properties.subscriptions) == 0 && length(azapi_resource.this.body.properties.addressPrefixes) == 0
    error_message = "Empty configured lists must be sent explicitly; this mock does not prove Azure clearing."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "reject_bad_direction" {
  command = plan
  variables {
    direction = "Invalid"
  }
  expect_failures = [var.direction]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "standalone_rule_extensions" {
  command = apply
  variables {
    lock = { kind = "CanNotDelete", name = "rule-lock" }
    role_assignments = {
      reader = {
        name                       = "00000000-0000-0000-0000-000000000010"
        principal_id               = "00000000-0000-0000-0000-000000000011"
        role_definition_id_or_name = "rg custom reader"
      }
    }
  }
  assert {
    condition     = output.extension_resource_ids.lock == "${var.parent_id}/accessRules/${var.name}/providers/Microsoft.Authorization/locks/rule-lock" && length(output.extension_resource_ids.role_assignments) == 1
    error_message = "Standalone access-rule extensions must stay at the rule scope."
  }
  assert {
    condition     = data.azapi_resource_list.role_definitions["child"].parent_id == "${var.parent_id}/accessRules/${var.name}" && random_uuid.role_assignment_name["reader"].keepers.scope == lower("${var.parent_id}/accessRules/${var.name}") && random_uuid.role_assignment_name["reader"].keepers.role_id == lower(azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId) && contains(azapi_resource.role_assignments["reader"].retry.error_message_regex, "PrincipalNotFound") && contains(azapi_resource.role_assignments["reader"].retry.error_message_regex, "LinkedAuthorizationFailed")
    error_message = "Rule lookup scope, identity-keyed UUIDs and standalone RBAC retry defaults must be retained."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}
