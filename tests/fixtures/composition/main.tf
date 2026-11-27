resource "terraform_data" "principal" {
  for_each = toset(["one", "two"])

  input = each.key
}

resource "terraform_data" "target" {
  count = var.mode == "association" ? 1 : 0

  input = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/test"
}

module "association" {
  source   = "../../../modules/resource_association"
  for_each = var.mode == "association" ? { target = true } : {}

  name                     = "association"
  parent_id                = "${local.parent_id}/providers/Microsoft.Network/networkSecurityPerimeters/local"
  private_link_resource_id = terraform_data.target[0].output
  profile_resource_id      = "${local.parent_id}/providers/Microsoft.Network/networkSecurityPerimeters/local/profiles/main"
  enable_telemetry         = false
  location                 = "eastus2"
  private_link_resource_extensions = {
    role_assignments = local.association_assignments
  }
  role_assignments = local.association_assignments
}

# No ID override: the mocked resource ID is genuinely unknown during PLAN.
module "remote" {
  source   = "../../.."
  for_each = local.remote_instances

  location         = "eastus2"
  name             = "remote"
  parent_id        = local.parent_id
  enable_telemetry = false
  link_references  = local.no_children
  links            = local.no_children
  lock             = local.no_lock
}

module "nested" {
  source   = "../../.."
  for_each = { for key, value in local.cases : key => value if startswith(var.mode, "nested_") }

  location         = "eastus2"
  name             = each.key
  parent_id        = local.parent_id
  enable_telemetry = false
  link_references = var.mode == "nested_reference" ? {
    composed = {
      name                         = "composed"
      role_assignments             = each.value.assignments
      remote_perimeter_resource_id = module.remote["remote"].resource_id
      remote_perimeter_extensions = {
        lock             = each.value.remote_lock
        role_assignments = each.value.assignments
      }
    }
  } : {}
  links = var.mode == "nested_link" ? {
    composed = {
      name                                       = "composed"
      role_assignments                           = each.value.assignments
      auto_approved_remote_perimeter_resource_id = module.remote["remote"].resource_id
      remote_perimeter_extensions = {
        lock             = each.value.remote_lock
        role_assignments = each.value.assignments
      }
    }
  } : {}
  lock = each.value.lock
}
