module "nsp_access_rule" {
  source   = "./modules/access_rule"
  for_each = var.access_rules

  direction                    = each.value.direction
  name                         = each.value.name
  profile_resource_id          = module.nsp_profile[each.value.profile_key].resource_id
  address_prefixes             = each.value.address_prefixes
  email_addresses              = each.value.email_addresses
  fully_qualified_domain_names = each.value.fully_qualified_domain_names
  phone_numbers                = each.value.phone_numbers
  service_tags                 = each.value.service_tags
  subscriptions                = each.value.subscriptions
}
