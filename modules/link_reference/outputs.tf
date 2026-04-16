output "name" {
  description = "The name of the link reference."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The full link reference resource object."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the link reference."
  value       = azapi_resource.this.id
}
