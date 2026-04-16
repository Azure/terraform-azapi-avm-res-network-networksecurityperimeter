output "name" {
  description = "The name of the NSP profile."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The full NSP profile resource object."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the NSP profile."
  value       = azapi_resource.this.id
}
