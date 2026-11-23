data "azapi_resource_list" "role_definitions" {
  for_each = local.role_lookup_scopes

  parent_id = each.key == "child" ? data.azapi_resource.this.id : each.value
  type      = var.resource_types.authorization_role_definitions
  response_export_values = {
    results = "value[].{id: id, role_name: properties.roleName}"
  }
}

module "avm" {
  source   = "Azure/avm-utl-interfaces/azure"
  version  = "0.10.0"
  for_each = local.extension_scopes

  enable_telemetry                          = false
  lock                                      = local.extension_locks[each.key]
  role_assignment_definition_lookup_enabled = false
  role_assignments                          = local.extension_assignments[each.key]
}

resource "terraform_data" "role_assignment_selector" {
  for_each = var.role_assignments

  triggers_replace = lower(each.value.role_definition_id_or_name)
}

resource "terraform_data" "target_role_assignment_selector" {
  for_each = local.extension_scopes.target.assignments

  triggers_replace = lower(each.value.role_definition_id_or_name)
}

resource "random_uuid" "role_assignment_name" {
  for_each = var.role_assignments

  keepers = {
    scope        = lower(local.extension_scopes.child.scope)
    principal_id = lower(each.value.principal_id)
    role_id      = lower(each.value.role_definition_id_or_name)
  }

  lifecycle {
    # Retain legacy resolved-ID keepers; the selector resource owns future role rotation.
    ignore_changes       = [keepers["role_id"]]
    replace_triggered_by = [terraform_data.role_assignment_selector[each.key]]
  }
}

resource "random_uuid" "target_role_assignment_name" {
  for_each = local.extension_scopes.target.assignments

  keepers = {
    scope        = lower(local.extension_scopes.target.scope)
    principal_id = lower(each.value.principal_id)
    role_id      = lower(each.value.role_definition_id_or_name)
  }

  lifecycle {
    ignore_changes       = [keepers["role_id"]]
    replace_triggered_by = [terraform_data.target_role_assignment_selector[each.key]]
  }
}

resource "azapi_resource" "role_assignments" {
  for_each = var.role_assignments

  name                 = coalesce(each.value.name, random_uuid.role_assignment_name[each.key].result)
  parent_id            = data.azapi_resource.this.id
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm["child"].role_assignments_azapi[each.key].body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_casing        = true
  ignore_null_property = true
  replace_triggers_external_values = {
    name                                   = each.value.name
    principal_id                           = lower(each.value.principal_id)
    role_definition_id                     = random_uuid.role_assignment_name[each.key].keepers.role_id
    principal_type                         = local.extension_assignments.child[each.key].principal_type
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
    # Keep an adopted GUID until an intentional immutable-input replacement.
    ignore_changes = [name]

    precondition {
      condition     = strcontains(lower(local.extension_assignments.child[each.key].role_definition_id_or_name), local.role_definition_resource_substring)
      error_message = "The role definition was not found at the assignable scope; supply an assignable role name or resource ID."
    }

    precondition {
      condition = random_uuid.role_assignment_name[each.key].keepers.role_id == lower(each.value.role_definition_id_or_name) ? true : (
        strcontains(random_uuid.role_assignment_name[each.key].keepers.role_id, local.role_definition_resource_substring) ?
        random_uuid.role_assignment_name[each.key].keepers.role_id == lower(local.extension_assignments.child[each.key].role_definition_id_or_name) : false
      )
      error_message = "The retained role ID does not match the resolved role. Keep the actual role unchanged for the first selector-migration apply; inspect the upgrade guide before changing it."
    }
  }
}

resource "azapi_resource" "target_role_assignments" {
  for_each = local.extension_scopes.target.assignments

  name                 = coalesce(each.value.name, random_uuid.target_role_assignment_name[each.key].result)
  parent_id            = local.extension_scopes.target.scope
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm["target"].role_assignments_azapi[each.key].body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_casing        = true
  ignore_null_property = true
  replace_triggers_external_values = {
    name                                   = each.value.name
    principal_id                           = lower(each.value.principal_id)
    role_definition_id                     = random_uuid.target_role_assignment_name[each.key].keepers.role_id
    principal_type                         = local.extension_assignments.target[each.key].principal_type
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
    # Keep an adopted GUID until an intentional immutable-input replacement.
    ignore_changes = [name]

    precondition {
      condition     = strcontains(lower(local.extension_assignments.target[each.key].role_definition_id_or_name), local.role_definition_resource_substring)
      error_message = "The role definition was not found at the assignable scope; supply an assignable role name or resource ID."
    }

    precondition {
      condition = random_uuid.target_role_assignment_name[each.key].keepers.role_id == lower(each.value.role_definition_id_or_name) ? true : (
        strcontains(random_uuid.target_role_assignment_name[each.key].keepers.role_id, local.role_definition_resource_substring) ?
        random_uuid.target_role_assignment_name[each.key].keepers.role_id == lower(local.extension_assignments.target[each.key].role_definition_id_or_name) : false
      )
      error_message = "The retained role ID does not match the resolved role. Keep the actual role unchanged for the first selector-migration apply; inspect the upgrade guide before changing it."
    }
  }
  depends_on = [terraform_data.remote_scope]
}

resource "azapi_resource" "lock" {
  count = var.lock == null ? 0 : 1

  name                   = module.avm["child"].lock_azapi.name
  parent_id              = data.azapi_resource.this.id
  type                   = var.resource_types.authorization_locks
  body                   = module.avm["child"].lock_azapi.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  replace_triggers_refs  = ["properties.level", "properties.notes"]
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

  depends_on = [azapi_resource.role_assignments]
}

resource "azapi_resource" "target_lock" {
  count = try(local.extension_scopes.target.lock, null) == null ? 0 : 1

  name                   = module.avm["target"].lock_azapi.name
  parent_id              = local.extension_scopes.target.scope
  type                   = var.resource_types.authorization_locks
  body                   = module.avm["target"].lock_azapi.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  replace_triggers_refs  = ["properties.level", "properties.notes"]
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

  depends_on = [terraform_data.remote_scope, azapi_resource.target_role_assignments]
}

resource "terraform_data" "remote_scope" {
  lifecycle {
    precondition {
      condition     = var.remote_perimeter_resource_id != null || (local.remote_perimeter_lock == null && length(var.remote_perimeter_extensions.role_assignments) == 0)
      error_message = "Remote extensions require a non-null remote_perimeter_resource_id; otherwise explicitly disable remote lock inheritance and leave remote RBAC empty."
    }
    precondition {
      condition     = var.remote_perimeter_resource_id == null ? true : lower(var.remote_perimeter_resource_id) == lower(try(data.azapi_resource.this.output.properties.remotePerimeterResourceId, ""))
      error_message = "The supplied remote perimeter must match the link reference GET response before remote extension writes."
    }
    precondition {
      condition     = var.remote_perimeter_resource_id == null ? true : lower(var.remote_perimeter_resource_id) != lower(var.parent_id)
      error_message = "A link reference must reference a different perimeter."
    }
  }
}
