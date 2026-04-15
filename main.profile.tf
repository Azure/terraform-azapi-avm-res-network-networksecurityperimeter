module "nsp_profile" {
  source   = "./modules/profile"
  for_each = var.profiles

  name                                   = each.value.name
  network_security_perimeter_resource_id = azapi_resource.network_security_perimeter.id
}
