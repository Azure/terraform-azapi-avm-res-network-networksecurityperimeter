module "nsp_profile" {
  source   = "./modules/profile"
  for_each = var.profiles

  name                = each.value.name
  parent_id           = azapi_resource.this.id
  enable_telemetry    = var.enable_telemetry
  ignore_body_changes = var.ignore_body_changes.network_network_security_perimeters_profiles
  location            = var.location
  lock                = each.value.lock
  resource_types      = var.resource_types.network_network_security_perimeters_profiles
  retry               = var.retry
  role_assignments    = each.value.role_assignments
  timeouts            = var.timeouts
}
