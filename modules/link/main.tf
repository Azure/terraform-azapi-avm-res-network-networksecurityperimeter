# Microsoft.Network/networkSecurityPerimeters/links@2025-05-01
resource "azapi_resource" "this" {
  name      = var.name
  parent_id = var.network_security_perimeter_resource_id
  type      = "Microsoft.Network/networkSecurityPerimeters/links@2025-05-01"
  body = {
    properties = {
      autoApprovedRemotePerimeterResourceId = var.auto_approved_remote_perimeter_resource_id
      description                           = var.description
      localInboundProfiles                  = var.local_inbound_profiles
      remoteInboundProfiles                 = var.remote_inbound_profiles
    }
  }
  response_export_values = []
}
