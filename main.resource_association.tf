module "nsp_resource_association" {
  source   = "./modules/resource_association"
  for_each = var.resource_associations

  name                                   = each.value.name
  network_security_perimeter_resource_id = azapi_resource.network_security_perimeter.id
  private_link_resource_id               = each.value.private_link_resource_id
  profile_resource_id                    = module.nsp_profile[each.value.profile_key].resource_id
  access_mode                            = each.value.access_mode
}
