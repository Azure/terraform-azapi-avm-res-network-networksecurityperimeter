module "nsp_resource_association" {
  source   = "./modules/resource_association"
  for_each = var.resource_associations

  name                     = each.value.name
  parent_id                = azapi_resource.this.id
  private_link_resource_id = each.value.private_link_resource_id
  profile_resource_id      = module.nsp_profile[each.value.profile_key].resource_id
  access_mode              = each.value.access_mode
  enable_telemetry         = var.enable_telemetry
  ignore_body_changes      = var.ignore_body_changes.network_network_security_perimeters_resource_associations
  location                 = var.location
  lock                     = each.value.lock
  private_link_resource_extensions = merge(each.value.private_link_resource_extensions, {
    lock                     = each.value.private_link_resource_extensions.lock != null ? each.value.private_link_resource_extensions.lock : var.lock
    lock_inheritance_enabled = each.value.private_link_resource_extensions.lock_inheritance_enabled && (each.value.private_link_resource_extensions.lock != null || var.lock != null)
  })
  resource_types   = var.resource_types.network_network_security_perimeters_resource_associations
  retry            = var.retry
  role_assignments = each.value.role_assignments
  timeouts         = var.timeouts
}
