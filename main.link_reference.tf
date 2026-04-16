module "nsp_link_reference" {
  source   = "./modules/link_reference"
  for_each = var.link_references

  name                                   = each.value.name
  network_security_perimeter_resource_id = azapi_resource.network_security_perimeter.id
}
