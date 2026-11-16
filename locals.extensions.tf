locals {
  perimeter_resource_id = "${var.parent_id}/providers/Microsoft.Network/networkSecurityPerimeters/${var.name}"
  extension_scopes = concat(
    [{ scope = local.perimeter_resource_id, lock = var.lock, assignments = var.role_assignments }],
    [for profile in var.profiles : {
      scope = "${local.perimeter_resource_id}/profiles/${profile.name}", lock = profile.lock, assignments = profile.role_assignments
    }],
    [for rule in var.access_rules : {
      scope = "${local.perimeter_resource_id}/profiles/${try(var.profiles[rule.profile_key].name, rule.profile_key)}/accessRules/${rule.name}", lock = rule.lock, assignments = rule.role_assignments
    }],
    [for association in var.resource_associations : {
      scope = "${local.perimeter_resource_id}/resourceAssociations/${association.name}", lock = association.lock, assignments = association.role_assignments
    }],
    [for association in var.resource_associations : {
      scope = association.private_link_resource_id
      lock = !association.private_link_resource_extensions.lock_inheritance_enabled ? null : (
        association.private_link_resource_extensions.lock != null ? association.private_link_resource_extensions.lock : var.lock
      )
      assignments = association.private_link_resource_extensions.role_assignments
    }],
    [for link in var.links : {
      scope = "${local.perimeter_resource_id}/links/${link.name}", lock = link.lock, assignments = link.role_assignments
    }],
    [for link in var.links : {
      scope = coalesce(link.auto_approved_remote_perimeter_resource_id, "unavailable")
      lock = !link.remote_perimeter_extensions.lock_inheritance_enabled ? null : (
        link.remote_perimeter_extensions.lock != null ? link.remote_perimeter_extensions.lock : var.lock
      )
      assignments = link.remote_perimeter_extensions.role_assignments
    }],
    [for reference in var.link_references : {
      scope = "${local.perimeter_resource_id}/linkReferences/${reference.name}", lock = reference.lock, assignments = reference.role_assignments
    }],
    [for reference in var.link_references : {
      scope = coalesce(reference.remote_perimeter_resource_id, "unavailable")
      lock = !reference.remote_perimeter_extensions.lock_inheritance_enabled ? null : (
        reference.remote_perimeter_extensions.lock != null ? reference.remote_perimeter_extensions.lock : var.lock
      )
      assignments = reference.remote_perimeter_extensions.role_assignments
    }],
  )
  extension_lock_scopes = [for target in local.extension_scopes : lower(trimsuffix(target.scope, "/")) if target.lock != null]
  extension_assignments = flatten([
    for target in local.extension_scopes : [
      for assignment in target.assignments : {
        scope      = lower(trimsuffix(target.scope, "/"))
        principal  = lower(assignment.principal_id)
        definition = assignment.role_definition_id_or_name
        name       = assignment.name
      }
    ]
  ])
  extension_role_lookup_scopes = {
    for index, assignment in local.extension_assignments :
    tostring(index) => assignment.scope
    if !strcontains(lower(assignment.definition), local.role_definition_resource_substring)
  }
  extension_role_ids = {
    for key, definitions in data.azapi_resource_list.extension_role_definitions : key => {
      for definition in definitions.output.results : lower(definition.role_name) => lower(definition.id)...
    }
  }
  extension_assignment_identities = [
    for index, assignment in local.extension_assignments : format(
      "%s|%s|%s", assignment.scope, assignment.principal, basename(
        !strcontains(lower(assignment.definition), local.role_definition_resource_substring) ?
        try(local.extension_role_ids[tostring(index)][lower(assignment.definition)][0], lower(assignment.definition)) :
        startswith(lower(assignment.definition), "/providers/") ?
        "${join("/", slice(split("/", assignment.scope), 0, 3))}${lower(assignment.definition)}" :
        lower(assignment.definition)
      )
    )
  ]
  extension_assignment_names = [for assignment in local.extension_assignments : lower(assignment.name) if assignment.name != null]
}
