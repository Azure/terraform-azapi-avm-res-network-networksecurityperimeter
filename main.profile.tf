module "nsp_profile" {
  source   = "./modules/profile"
  for_each = var.profiles

  location                               = var.location
  name                                   = each.value.name
  network_security_perimeter_resource_id = azapi_resource.network_security_perimeter.id
  enable_telemetry                       = var.enable_telemetry
}
