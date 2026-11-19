resource "terraform_data" "target" {
  input = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/test"
}

resource "terraform_data" "principal" {
  for_each = toset(["one", "two"])

  input = each.key
}

module "association" {
  source = "../../../modules/resource_association"

  name                     = "association"
  parent_id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/local"
  private_link_resource_id = terraform_data.target.output
  profile_resource_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/local/profiles/main"
  enable_telemetry         = false
  location                 = "eastus2"
  private_link_resource_extensions = {
    role_assignments = local.assignments
  }
  role_assignments = local.assignments
}
