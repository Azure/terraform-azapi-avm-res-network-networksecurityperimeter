# PLAN only: both remote IDs and principal IDs stay unknown; keys stay static.
# No managed-resource ID overrides that could hide unknown-value failures.
mock_provider "azapi" {
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        }]
      }
    }
  }
  mock_data "azapi_resource" {
    defaults = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/local/linkReferences/existing"
      output = { properties = { remotePerimeterResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote" } }
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

run "role_lookup_with_known_parent_scope" {
  command = plan
  module {
    source = "./tests/fixtures/role_lookup"
  }
  assert {
    condition     = keys(module.perimeter.profiles) == ["profile"] && keys(module.perimeter.access_rules) == ["rule"]
    error_message = "Fresh scopes with name-based roles must plan without an ownership dependency cycle."
  }
}

run "link" {
  command = plan
  module {
    source = "./tests/fixtures/link_composition"
  }
  assert {
    condition     = length(module.link) == 5
    error_message = "All five configured extension shapes must plan with an unknown remote resource output."
  }
  assert {
    condition     = keys(module.link["role_id"].extension_resource_ids.role_assignments) == ["reader"] && keys(module.link["role_name"].extension_resource_ids.role_assignments) == ["reader"]
    error_message = "Standalone link assignment addresses must retain configured keys with unknown principal and remote IDs."
  }
}

run "reference" {
  command = plan
  module {
    source = "./tests/fixtures/reference_composition"
  }
  assert {
    condition     = length(module.reference) == 5
    error_message = "GET-only reference extensions must plan with an unknown remote resource output."
  }
  assert {
    condition     = keys(module.reference["role_id"].extension_resource_ids.role_assignments) == ["reader"] && keys(module.reference["role_name"].extension_resource_ids.role_assignments) == ["reader"]
    error_message = "Standalone reference assignment addresses must retain configured keys with unknown principal and remote IDs."
  }
}

run "nested_link" {
  command = plan
  module {
    source = "./tests/fixtures/composition"
  }
  variables {
    mode = "nested_link"
  }
  assert {
    condition     = length(module.nested) == 5 && alltrue([for instance in module.nested : length(instance.links) == 1])
    error_message = "Nested links must accept unknown remote module IDs."
  }
  assert {
    condition     = keys(module.nested["role_id"].links.composed.extension_resource_ids.role_assignments) == ["reader"] && keys(module.nested["role_name"].links.composed.extension_resource_ids.role_assignments) == ["reader"]
    error_message = "Nested link assignment addresses must retain configured keys with unknown principal and remote IDs."
  }
}

run "nested_reference" {
  command = plan
  module {
    source = "./tests/fixtures/composition"
  }
  variables {
    mode = "nested_reference"
  }
  assert {
    condition     = length(module.nested) == 5 && alltrue([for instance in module.nested : length(instance.link_references) == 1])
    error_message = "Nested references must accept unknown remote module IDs."
  }
  assert {
    condition     = keys(module.nested["role_id"].link_references.composed.extension_resource_ids.role_assignments) == ["reader"] && keys(module.nested["role_name"].link_references.composed.extension_resource_ids.role_assignments) == ["reader"]
    error_message = "Nested reference assignment addresses must retain configured keys with unknown principal and remote IDs."
  }
}

run "association" {
  command = plan
  module {
    source = "./tests/fixtures/composition"
  }
  variables {
    mode = "association"
  }
  assert {
    condition     = keys(module.association["target"].extension_resource_ids.role_assignments) == ["lookup", "reader"]
    error_message = "Association assignment addresses must retain configured keys with unknown principal and target IDs."
  }
}

run "null_targets" {
  command = plan
  variables {
    name             = "manual"
    parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test"
    location         = "eastus2"
    enable_telemetry = false
    links            = { manual = { name = "manual" } }
    link_references  = { existing = { name = "existing" } }
  }
  assert {
    condition     = output.links["manual"].extension_resource_ids.remote_perimeter == null && output.link_references["existing"].extension_resource_ids.remote_perimeter == null
    error_message = "Null optional target IDs without extensions must not force target instances or unknown for_each keys."
  }
}
