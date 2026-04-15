output "access_rules" {
  description = "A map of the NSP access rule submodule outputs. Keyed by the map key used in var.access_rules."
  value       = module.nsp_access_rule
}

output "link_references" {
  description = "A map of the NSP link reference submodule outputs. Keyed by the map key used in var.link_references."
  value       = module.nsp_link_reference
}

output "links" {
  description = "A map of the NSP link submodule outputs. Keyed by the map key used in var.links."
  value       = module.nsp_link
}

output "name" {
  description = "The name of the network security perimeter."
  value       = azapi_resource.network_security_perimeter.name
}

# NSP-specific outputs
output "profiles" {
  description = "A map of the NSP profile submodule outputs. Keyed by the map key used in var.profiles."
  value       = module.nsp_profile
}

# AVM required outputs
output "resource" {
  description = "The full network security perimeter resource object."
  value       = azapi_resource.network_security_perimeter
}

output "resource_associations" {
  description = "A map of the NSP resource association submodule outputs. Keyed by the map key used in var.resource_associations."
  value       = module.nsp_resource_association
}

output "resource_id" {
  description = "The resource ID of the network security perimeter."
  value       = azapi_resource.network_security_perimeter.id
}
