locals {
  extension_scopes = {
    child = {
      scope       = "${trimsuffix(var.parent_id, "/")}/profiles/${var.name}"
      lock        = var.lock
      assignments = var.role_assignments
    }
  }
  role_definition_resource_substring = "/providers/microsoft.authorization/roledefinitions/"
  role_definition_scopes = {
    for key, target in local.extension_scopes : key =>
    startswith(lower(target.scope), "/subscriptions/") ? join("/", slice(split("/", target.scope), 0, 3)) : target.scope
  }
  role_lookup_scopes = {
    for key, target in local.extension_scopes : key => target.scope
    if anytrue([for assignment in target.assignments : !strcontains(lower(assignment.role_definition_id_or_name), local.role_definition_resource_substring)])
  }
  role_definition_ids_by_name = {
    for key, definitions in data.azapi_resource_list.role_definitions : key => {
      for definition in definitions.output.results : lower(definition.role_name) => definition.id...
    }
  }
  extension_locks = {
    for key, target in local.extension_scopes : key => target.lock == null ? null : merge(target.lock, {
      name  = coalesce(target.lock.name, "lock-${target.lock.kind}")
      notes = coalesce(target.lock.notes, target.lock.kind == "ReadOnly" ? "Cannot delete or modify the resource or its child resources." : "Cannot delete the resource or its child resources.")
    })
  }
  extension_assignments = {
    for scope_key, target in local.extension_scopes : scope_key => {
      for key, assignment in target.assignments : key => merge(assignment, {
        principal_type = assignment.principal_type == null && assignment.skip_service_principal_aad_check ? "ServicePrincipal" : assignment.principal_type
        role_definition_id_or_name = (
          !strcontains(lower(assignment.role_definition_id_or_name), local.role_definition_resource_substring) ?
          try(local.role_definition_ids_by_name[scope_key][lower(assignment.role_definition_id_or_name)][0], assignment.role_definition_id_or_name) :
          startswith(lower(assignment.role_definition_id_or_name), "/providers/") && startswith(lower(target.scope), "/subscriptions/") ?
          "${local.role_definition_scopes[scope_key]}${assignment.role_definition_id_or_name}" :
          assignment.role_definition_id_or_name
        )
      })
    }
  }
}
