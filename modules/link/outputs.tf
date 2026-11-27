output "extension_resource_ids" {
  description = "Link and externally owned remote-perimeter extension IDs."
  value = {
    lock             = var.lock == null ? null : "${local.extension_scopes.child.scope}/providers/Microsoft.Authorization/locks/${module.avm["child"].lock_azapi.name}"
    role_assignments = { for key, assignment in azapi_resource.role_assignments : key => assignment.id }
    remote_perimeter = var.auto_approved_remote_perimeter_resource_id == null ? null : {
      lock             = local.remote_perimeter_lock == null ? null : "${local.extension_scopes.target.scope}/providers/Microsoft.Authorization/locks/${module.avm["target"].lock_azapi.name}"
      role_assignments = { for key, assignment in azapi_resource.target_role_assignments : key => assignment.id }
    }
  }
}

output "name" {
  description = "The name of the NSP link."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "Stable link identity attributes."
  value = {
    id   = azapi_resource.this.id
    name = azapi_resource.this.name
  }
}

output "resource_id" {
  description = "The resource ID of the NSP link."
  value       = azapi_resource.this.id
}
