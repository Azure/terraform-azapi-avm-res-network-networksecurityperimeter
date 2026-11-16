# -------------------------------------------------------------------------
# Core resource: Microsoft.Network/networkSecurityPerimeters
# API version: 2025-05-01
# -------------------------------------------------------------------------
resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.network_network_security_perimeters
  body = {
    properties = {}
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_network_security_perimeters) > 0 ? var.ignore_body_changes.network_network_security_perimeters : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  depends_on = [terraform_data.extension_ownership]
}
