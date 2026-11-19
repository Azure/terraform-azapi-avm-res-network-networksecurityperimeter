locals {
  assignments = {
    reader = {
      principal_id               = terraform_data.principal["one"].output
      role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    }
    lookup = {
      principal_id               = terraform_data.principal["two"].output
      role_definition_id_or_name = "Reader"
    }
  }
}
