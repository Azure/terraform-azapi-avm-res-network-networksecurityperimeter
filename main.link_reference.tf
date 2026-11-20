module "nsp_link_reference" {
  source   = "./modules/link_reference"
  for_each = var.link_references

  name                = each.value.name
  parent_id           = azapi_resource.this.id
  enable_telemetry    = var.enable_telemetry
  ignore_body_changes = var.ignore_body_changes.network_network_security_perimeters_link_references
  location            = var.location
  lock                = each.value.lock
  remote_perimeter_extensions = merge(each.value.remote_perimeter_extensions, {
    lock                     = each.value.remote_perimeter_extensions.lock != null ? each.value.remote_perimeter_extensions.lock : var.lock
    lock_inheritance_enabled = each.value.remote_perimeter_extensions.lock_inheritance_enabled && (each.value.remote_perimeter_extensions.lock != null || var.lock != null)
  })
  remote_perimeter_resource_id = each.value.remote_perimeter_resource_id
  resource_types               = var.resource_types.network_network_security_perimeters_link_references
  retry                        = var.retry
  role_assignments             = each.value.role_assignments
  timeouts                     = var.timeouts
}
