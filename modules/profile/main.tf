# Microsoft.Network/networkSecurityPerimeters/profiles@2025-05-01
resource "azapi_resource" "this" {
  name      = var.name
  parent_id = var.network_security_perimeter_resource_id
  type      = "Microsoft.Network/networkSecurityPerimeters/profiles@2025-05-01"
  body = {
    properties = {}
  }
  response_export_values = []
}
