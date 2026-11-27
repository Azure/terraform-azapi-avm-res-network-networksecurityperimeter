module "nsp_access_rule" {
  source   = "./modules/access_rule"
  for_each = var.access_rules

  direction                    = each.value.direction
  name                         = each.value.name
  parent_id                    = module.nsp_profile[each.value.profile_key].resource_id
  address_prefixes             = each.value.address_prefixes
  email_addresses              = each.value.email_addresses
  enable_telemetry             = var.enable_telemetry
  fully_qualified_domain_names = each.value.fully_qualified_domain_names
  ignore_body_changes          = var.ignore_body_changes.network_network_security_perimeters_profiles_access_rules
  location                     = var.location
  lock                         = each.value.lock
  phone_numbers                = each.value.phone_numbers
  resource_types               = var.resource_types.network_network_security_perimeters_profiles_access_rules
  retry                        = var.retry
  role_assignments             = each.value.role_assignments
  service_tags                 = each.value.service_tags
  subscriptions                = each.value.subscriptions
  timeouts                     = var.timeouts
}
