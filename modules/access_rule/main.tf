# Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2025-05-01
resource "azapi_resource" "this" {
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.network_network_security_perimeters_profiles_access_rules
  body = {
    properties = {
      addressPrefixes           = var.address_prefixes
      direction                 = var.direction
      emailAddresses            = var.email_addresses
      fullyQualifiedDomainNames = var.fully_qualified_domain_names
      phoneNumbers              = var.phone_numbers
      serviceTags               = var.service_tags
      subscriptions             = [for sub in var.subscriptions : { id = sub }]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_network_security_perimeters_profiles_access_rules) > 0 ? var.ignore_body_changes.network_network_security_perimeters_profiles_access_rules : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
