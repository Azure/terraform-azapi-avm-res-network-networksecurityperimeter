# Microsoft.Network/networkSecurityPerimeters/links@2025-05-01
resource "azapi_resource" "this" {
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.network_network_security_perimeters_links
  body = {
    properties = {
      autoApprovedRemotePerimeterResourceId = var.auto_approved_remote_perimeter_resource_id
      description                           = var.description
      localInboundProfiles                  = var.local_inbound_profiles
      remoteInboundProfiles                 = var.remote_inbound_profiles
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_network_security_perimeters_links) > 0 ? var.ignore_body_changes.network_network_security_perimeters_links : null
  replace_triggers_refs  = ["properties.autoApprovedRemotePerimeterResourceId"]
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

  depends_on = [terraform_data.remote_scope]
}
