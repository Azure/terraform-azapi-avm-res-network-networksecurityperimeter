module "nsp_link" {
  source   = "./modules/link"
  for_each = var.links

  name                                       = each.value.name
  parent_id                                  = azapi_resource.this.id
  auto_approved_remote_perimeter_resource_id = each.value.auto_approved_remote_perimeter_resource_id
  description                                = each.value.description
  enable_telemetry                           = var.enable_telemetry
  ignore_body_changes                        = var.ignore_body_changes.network_network_security_perimeters_links
  # Depend on profile resources, not their locks/RBAC or the entire module.
  local_inbound_profiles = [
    for name in each.value.local_inbound_profiles :
    lookup({ for key, profile in var.profiles : profile.name => module.nsp_profile[key].name }, name, name)
  ]
  location                = var.location
  lock                    = each.value.lock
  remote_inbound_profiles = each.value.remote_inbound_profiles
  remote_perimeter_extensions = merge(each.value.remote_perimeter_extensions, {
    lock                     = each.value.remote_perimeter_extensions.lock != null ? each.value.remote_perimeter_extensions.lock : var.lock
    lock_inheritance_enabled = each.value.remote_perimeter_extensions.lock_inheritance_enabled && (each.value.remote_perimeter_extensions.lock != null || var.lock != null)
  })
  resource_types   = var.resource_types.network_network_security_perimeters_links
  retry            = var.retry
  role_assignments = each.value.role_assignments
  timeouts         = var.timeouts
}
