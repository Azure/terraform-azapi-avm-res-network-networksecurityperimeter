output "extension_resource_ids" {
  description = "Profile-owned extension IDs; the root does not create duplicate child extensions."
  value = {
    lock             = var.lock == null ? null : "${local.extension_scopes.child.scope}/providers/Microsoft.Authorization/locks/${module.avm["child"].lock_azapi.name}"
    role_assignments = { for key, assignment in azapi_resource.role_assignments : key => assignment.id }
  }
}

output "name" {
  description = "The name of the NSP profile."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "Stable profile identity attributes."
  value = {
    id   = azapi_resource.this.id
    name = azapi_resource.this.name
  }
}

output "resource_id" {
  description = "The resource ID of the NSP profile."
  value       = azapi_resource.this.id
}
