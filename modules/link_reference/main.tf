# The service creates the counterpart. No PUT operation exists in this API.
data "azapi_resource" "this" {
  name                   = var.name
  parent_id              = var.parent_id
  type                   = var.resource_types.network_network_security_perimeters_link_references
  response_export_values = ["properties"]
}

removed {
  from = azapi_resource.this
  lifecycle {
    destroy = false
  }
}
