# PLAN only: no mock ID defaults/overrides that could hide unknown-ID failures.
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

run "link" {
  command = plan
  module {
    source = "./tests/fixtures/link_composition"
  }
  assert {
    condition     = length(module.link) == 5
    error_message = "All five configured extension shapes must plan with an unknown remote resource output."
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
    error_message = "Root ownership bookkeeping and nested links must accept unknown remote module IDs."
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
    error_message = "Root ownership bookkeeping and nested references must accept unknown remote module IDs."
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
