# Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2025-05-01
resource "azapi_resource" "this" {
  name      = var.name
  parent_id = var.profile_resource_id
  type      = "Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2025-05-01"
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
  response_export_values = []
}
