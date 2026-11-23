data "azapi_resource_list" "role_definitions" {
  count = anytrue([for assignment in var.role_assignments : !strcontains(lower(assignment.role_definition_id_or_name), local.role_definition_resource_substring)]) ? 1 : 0

  parent_id = azapi_resource.this.id
  type      = var.resource_types.authorization_role_definitions
  response_export_values = {
    results = "value[].{id: id, role_name: properties.roleName}"
  }
}

module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.10.0"

  enable_telemetry                          = var.enable_telemetry
  location                                  = var.location
  lock                                      = local.lock
  role_assignment_definition_lookup_enabled = false
  role_assignments                          = local.role_assignments
}

resource "terraform_data" "role_assignment_selector" {
  for_each = var.role_assignments

  triggers_replace = lower(each.value.role_definition_id_or_name)
}

resource "random_uuid" "role_assignment_name" {
  for_each = var.role_assignments

  keepers = {
    scope        = lower(trimsuffix(local.perimeter_resource_id, "/"))
    principal_id = lower(each.value.principal_id)
    role_id      = lower(each.value.role_definition_id_or_name)
  }

  lifecycle {
    # Retain legacy resolved-ID keepers; the selector resource owns future role rotation.
    ignore_changes       = [keepers["role_id"]]
    replace_triggered_by = [terraform_data.role_assignment_selector[each.key]]
  }
}

resource "azapi_resource" "role_assignments" {
  for_each = var.role_assignments

  name                 = coalesce(each.value.name, random_uuid.role_assignment_name[each.key].result)
  parent_id            = azapi_resource.this.id
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm_interfaces.role_assignments_azapi[each.key].body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_casing        = true
  ignore_null_property = true
  replace_triggers_external_values = {
    name                                   = each.value.name
    principal_id                           = lower(each.value.principal_id)
    role_definition_id                     = random_uuid.role_assignment_name[each.key].keepers.role_id
    principal_type                         = local.role_assignments[each.key].principal_type
    description                            = each.value.description
    condition                              = each.value.condition
    condition_version                      = each.value.condition_version
    delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  }
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    # Preserve the GUID adopted from AzureRM rather than replacing it with a new utility UUID.
    ignore_changes = [name]
    precondition {
      condition     = strcontains(lower(local.role_assignments[each.key].role_definition_id_or_name), local.role_definition_resource_substring)
      error_message = "The role definition was not found at the assignable scope; supply an assignable role name or resource ID."
    }

    precondition {
      condition = random_uuid.role_assignment_name[each.key].keepers.role_id == lower(each.value.role_definition_id_or_name) ? true : (
        strcontains(random_uuid.role_assignment_name[each.key].keepers.role_id, local.role_definition_resource_substring) ?
        random_uuid.role_assignment_name[each.key].keepers.role_id == lower(local.role_assignments[each.key].role_definition_id_or_name) : false
      )
      error_message = "The retained role ID does not match the resolved role. Keep the actual role unchanged for the first selector-migration apply; inspect the upgrade guide before changing it."
    }
  }
}
