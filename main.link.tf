module "nsp_link" {
  source   = "./modules/link"
  for_each = var.links

  name                                       = each.value.name
  network_security_perimeter_resource_id     = azapi_resource.network_security_perimeter.id
  auto_approved_remote_perimeter_resource_id = each.value.auto_approved_remote_perimeter_resource_id
  description                                = each.value.description
  local_inbound_profiles                     = each.value.local_inbound_profiles
  remote_inbound_profiles                    = each.value.remote_inbound_profiles
}
