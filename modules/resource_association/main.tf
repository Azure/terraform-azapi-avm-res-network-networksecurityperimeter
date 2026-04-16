# Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2025-05-01
resource "azapi_resource" "this" {
  name      = var.name
  parent_id = var.network_security_perimeter_resource_id
  type      = "Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2025-05-01"
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
  response_export_values = []
}
