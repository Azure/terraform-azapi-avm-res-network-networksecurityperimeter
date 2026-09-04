# -------------------------------------------------------------------------
# Core resource: Microsoft.Network/networkSecurityPerimeters
# API version: 2025-05-01
# -------------------------------------------------------------------------
resource "azapi_resource" "network_security_perimeter" {
  location  = var.location
  name      = var.name
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  type      = "Microsoft.Network/networkSecurityPerimeters@2025-05-01"
  body = {
    properties = {}
  }
  response_export_values = []
  tags                   = var.tags
}
