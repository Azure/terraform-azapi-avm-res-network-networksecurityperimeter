# Plan-only fixture: its runner uses synthetic state and never applies Azure resources.
provider "azapi" {
  # Deliberately invalid offline credentials: never reuse a signed-in Azure context.
  subscription_id = "00000000-0000-0000-0000-000000000000"
  tenant_id       = "00000000-0000-0000-0000-000000000000"
  client_id       = "00000000-0000-0000-0000-000000000000"
  client_secret   = "invalid-offline-fixture-not-a-secret"
  use_cli         = false
  use_msi         = false
  use_oidc        = false
}

resource "terraform_data" "dep" {
  input = var.dependency_revision
}

module "perimeter" {
  source = "../../.."

  location         = "eastus2"
  name             = "nsp-role-identity"
  parent_id        = local.parent_id
  enable_telemetry = false
  role_assignments = local.role_assignments

  depends_on = [terraform_data.dep]
}

module "profile" {
  source = "../../../modules/profile"

  name             = "profile"
  parent_id        = local.perimeter_id
  enable_telemetry = false
  role_assignments = local.role_assignments

  depends_on = [terraform_data.dep]
}

module "access_rule" {
  source = "../../../modules/access_rule"

  direction        = "Inbound"
  name             = "rule"
  parent_id        = "${local.perimeter_id}/profiles/profile"
  address_prefixes = ["203.0.113.0/24"]
  enable_telemetry = false
  role_assignments = local.role_assignments

  depends_on = [terraform_data.dep]
}

module "association" {
  source = "../../../modules/resource_association"

  name                     = "association"
  parent_id                = local.perimeter_id
  private_link_resource_id = "${local.parent_id}/providers/Microsoft.Storage/storageAccounts/external"
  profile_resource_id      = "${local.perimeter_id}/profiles/profile"
  enable_telemetry         = false
  private_link_resource_extensions = {
    lock_inheritance_enabled = false
    role_assignments         = local.role_assignments
  }
  role_assignments = local.role_assignments

  depends_on = [terraform_data.dep]
}

module "link" {
  source = "../../../modules/link"

  name                                       = "link"
  parent_id                                  = local.perimeter_id
  auto_approved_remote_perimeter_resource_id = local.remote_id
  enable_telemetry                           = false
  remote_perimeter_extensions = {
    lock_inheritance_enabled = false
    role_assignments         = local.role_assignments
  }
  role_assignments = local.role_assignments

  depends_on = [terraform_data.dep]
}

module "reference" {
  source = "../../../modules/link_reference"

  name             = "reference"
  parent_id        = local.perimeter_id
  enable_telemetry = false
  lock             = { kind = "CanNotDelete" }
  remote_perimeter_extensions = {
    lock_inheritance_enabled = false
    role_assignments         = local.role_assignments
  }
  remote_perimeter_resource_id = local.remote_id
  role_assignments             = local.role_assignments

  depends_on = [terraform_data.dep]
}
