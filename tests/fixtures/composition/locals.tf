locals {
  remote_instances = { remote = true }
  no_lock          = null
  no_children      = {}
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test"
  cases = {
    no_extensions  = { lock = null, remote_lock = null, assignments = {} }
    explicit_lock  = { lock = null, remote_lock = { kind = "CanNotDelete" }, assignments = {} }
    inherited_lock = { lock = { kind = "CanNotDelete" }, remote_lock = null, assignments = {} }
    role_name = {
      lock = null, remote_lock = null
      assignments = { reader = {
        principal_id               = terraform_data.principal["one"].output
        role_definition_id_or_name = "Reader"
      } }
    }
    role_id = {
      lock = null, remote_lock = null
      assignments = { reader = {
        principal_id               = terraform_data.principal["two"].output
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      } }
    }
  }
}
