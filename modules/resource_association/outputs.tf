output "extension_resource_ids" {
  description = "Association and externally owned PaaS target extension IDs; target lifecycle remains external."
  value = {
    lock             = var.lock == null ? null : "${local.extension_scopes.child.scope}/providers/Microsoft.Authorization/locks/${module.avm["child"].lock_azapi.name}"
    role_assignments = { for key, assignment in azapi_resource.role_assignments : key => assignment.id }
    private_link_resource = {
      lock             = local.private_link_resource_lock == null ? null : "${local.extension_scopes.target.scope}/providers/Microsoft.Authorization/locks/${module.avm["target"].lock_azapi.name}"
      role_assignments = { for key, assignment in azapi_resource.target_role_assignments : key => assignment.id }
    }
  }
}

output "name" {
  description = "The name of the resource association."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "Stable association identity attributes."
  value = {
    id   = azapi_resource.this.id
    name = azapi_resource.this.name
  }
}

output "resource_id" {
  description = "The resource ID of the resource association."
  value       = azapi_resource.this.id
}
