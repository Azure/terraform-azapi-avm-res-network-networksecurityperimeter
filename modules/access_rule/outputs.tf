output "name" {
  description = "The name of the access rule."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The full access rule resource object."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the access rule."
  value       = azapi_resource.this.id
}
