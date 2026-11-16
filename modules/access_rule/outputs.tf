output "extension_resource_ids" {
  description = "Access-rule-owned extension IDs."
  value = {
    lock             = var.lock == null ? null : "${local.extension_scopes.child.scope}/providers/Microsoft.Authorization/locks/${module.avm["child"].lock_azapi.name}"
    role_assignments = { for key, assignment in azapi_resource.role_assignments : key => assignment.id }
  }
}

output "name" {
  description = "The name of the access rule."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "Stable access rule identity attributes."
  value = {
    id   = azapi_resource.this.id
    name = azapi_resource.this.name
  }
}

output "resource_id" {
  description = "The resource ID of the access rule."
  value       = azapi_resource.this.id
}
