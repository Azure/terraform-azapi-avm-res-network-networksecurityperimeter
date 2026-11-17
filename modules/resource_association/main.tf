# Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2025-05-01
resource "azapi_resource" "this" {
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.network_network_security_perimeters_resource_associations
  body = {
    properties = {
      accessMode = var.access_mode
      privateLinkResource = {
        id = var.private_link_resource_id
      }
      profile = {
        id = var.profile_resource_id
      }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_network_security_perimeters_resource_associations) > 0 ? var.ignore_body_changes.network_network_security_perimeters_resource_associations : null
  replace_triggers_refs  = ["properties.privateLinkResource.id"]
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
