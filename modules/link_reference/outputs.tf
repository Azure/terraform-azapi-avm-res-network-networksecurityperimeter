output "extension_resource_ids" {
  description = "Owned extension IDs only; neither reference nor remote perimeter becomes a lifecycle resource."
  value = {
    lock             = var.lock == null ? null : "${local.extension_scopes.child.scope}/providers/Microsoft.Authorization/locks/${module.avm["child"].lock_azapi.name}"
    role_assignments = { for key, assignment in azapi_resource.role_assignments : key => assignment.id }
    remote_perimeter = var.remote_perimeter_resource_id == null ? null : {
      lock             = local.remote_perimeter_lock == null ? null : "${local.extension_scopes.target.scope}/providers/Microsoft.Authorization/locks/${module.avm["target"].lock_azapi.name}"
      role_assignments = { for key, assignment in azapi_resource.target_role_assignments : key => assignment.id }
    }
  }
}

output "name" {
  description = "The name of the link reference."
  value       = data.azapi_resource.this.name
}

output "resource" {
  description = "The existing link reference identity and observed properties; this module does not own its lifecycle."
  value = {
    id         = data.azapi_resource.this.id
    name       = data.azapi_resource.this.name
    properties = data.azapi_resource.this.output.properties
  }
}

output "resource_id" {
  description = "The resource ID of the link reference."
  value       = data.azapi_resource.this.id
}
