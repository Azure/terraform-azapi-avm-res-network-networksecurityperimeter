output "name" {
  description = "The name of the NSP link."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The full NSP link resource object."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the NSP link."
  value       = azapi_resource.this.id
}
