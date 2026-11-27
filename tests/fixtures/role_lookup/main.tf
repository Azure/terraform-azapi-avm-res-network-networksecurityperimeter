# Known names and parent scope must not cause reads before the owned scopes exist.
module "perimeter" {
  source = "../../.."

  location  = "eastus2"
  name      = "nsp-role-lookup"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test"
  access_rules = {
    rule = {
      name             = "rule"
      profile_key      = "profile"
      direction        = "Inbound"
      address_prefixes = ["203.0.113.0/24"]
      role_assignments = local.role_assignments
    }
  }
  enable_telemetry = false
  profiles = {
    profile = {
      name             = "profile"
      role_assignments = local.role_assignments
    }
  }
  role_assignments = local.role_assignments
}

# Standalone children must also wait for their own resource, not just its parent.
module "profile" {
  source = "../../../modules/profile"

  name             = "standalone"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/existing"
  enable_telemetry = false
  role_assignments = local.role_assignments
}
