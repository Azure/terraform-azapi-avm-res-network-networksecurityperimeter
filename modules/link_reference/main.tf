# Microsoft.Network/networkSecurityPerimeters/linkReferences@2025-05-01
#
# Link references are automatically created on the remote NSP when an NSP link
# is established. All properties are read-only in the current API version.
resource "azapi_resource" "this" {
  name                   = var.name
  parent_id              = var.network_security_perimeter_resource_id
  type                   = "Microsoft.Network/networkSecurityPerimeters/linkReferences@2025-05-01"
  body                   = {}
  response_export_values = []
}
