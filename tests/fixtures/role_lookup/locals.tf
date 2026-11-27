locals {
  role_assignments = {
    reader = {
      principal_id               = "00000000-0000-0000-0000-000000000001"
      role_definition_id_or_name = "Reader"
    }
  }
}
