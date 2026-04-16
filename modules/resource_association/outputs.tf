output "name" {
  description = "The name of the resource association."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The full resource association resource object."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the resource association."
  value       = azapi_resource.this.id
}
