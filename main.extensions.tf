data "azapi_resource_list" "extension_role_definitions" {
  for_each = local.extension_role_lookup_scopes

  # Lookup at the assignment scope so RG-scoped custom roles remain visible.
  parent_id = each.value
  type      = var.resource_types.authorization_role_definitions
  response_export_values = {
    results = "value[].{id: id, role_name: properties.roleName}"
  }
}

resource "terraform_data" "extension_ownership" {
  input = true

  lifecycle {
    precondition {
      condition     = length(distinct(local.extension_lock_scopes)) == length(local.extension_lock_scopes)
      error_message = "Exactly one lock owner is allowed per normalized ARM target, including repeated references and different paths. Choose one owner and disable lock inheritance on the others."
    }
    precondition {
      condition     = length(distinct(local.extension_assignment_identities)) == length(local.extension_assignment_identities)
      error_message = "Duplicate scope/principal/resolved-role assignments are not allowed, including role name/ID aliases and cross-referenced paths."
    }
    precondition {
      condition     = length(distinct(local.extension_assignment_names)) == length(local.extension_assignment_names)
      error_message = "Explicit role assignment GUIDs must be globally unique across this module's scopes."
    }
    precondition {
      condition     = alltrue([for target in local.extension_scopes : target.scope != "unavailable" || (target.lock == null && length(target.assignments) == 0)])
      error_message = "Remote extension management requires a non-null ARM remote perimeter ID. Otherwise disable that target's lock inheritance and leave RBAC empty."
    }
  }
}
