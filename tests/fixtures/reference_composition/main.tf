# terraform_data.output stays unknown during PLAN, unlike a configured input.
resource "terraform_data" "remote" {
  input = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
}

module "reference" {
  source   = "../../../modules/link_reference"
  for_each = local.cases

  name             = each.key
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/local"
  enable_telemetry = false
  location         = "eastus2"
  lock             = each.value.lock
  remote_perimeter_extensions = {
    lock             = each.value.remote_lock
    role_assignments = each.value.assignments
  }
  remote_perimeter_resource_id = terraform_data.remote.output
}
