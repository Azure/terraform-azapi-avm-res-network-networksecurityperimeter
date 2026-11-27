locals {
  parent_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test${var.scope_suffix}"
  perimeter_id = "${local.parent_id}/providers/Microsoft.Network/networkSecurityPerimeters/existing"
  remote_id    = "${local.parent_id}/providers/Microsoft.Network/networkSecurityPerimeters/remote"
  role_assignments = {
    reader = {
      name                       = var.assignment_name
      principal_id               = var.principal_id
      role_definition_id_or_name = var.role_selector
    }
  }
}
