mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
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
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-test/linkReferences/b"
      output = { properties = { remotePerimeterResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote" } }
    }
  }
}

mock_provider "random" {}

variables {
  name             = "nsp-test"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test"
  location         = "eastus2"
  enable_telemetry = false
}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-test"
  }
}

run "child_and_external_owners" {
  command = apply
  override_resource {
    target = module.nsp_access_rule["rule"].azapi_resource.this
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-test/profiles/profile/accessRules/rule"
    }
  }
  override_resource {
    target = module.nsp_link["remote"].azapi_resource.this
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-test/links/remote"
    }
  }
  override_resource {
    target = module.nsp_resource_association["storage"].azapi_resource.target_role_assignments["reader"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/external/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000020"
    }
  }
  override_resource {
    target = module.nsp_profile["profile"].azapi_resource.this
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-test/profiles/profile"
    }
  }
  variables {
    lock = { kind = "CanNotDelete", name = "primary-lock" }
    resource_types = {
      network_network_security_perimeters_profiles = {
        authorization_locks = "Microsoft.Authorization/locks@2016-09-01"
      }
      network_network_security_perimeters_resource_associations = {
        authorization_locks            = null
        authorization_role_assignments = "Microsoft.Authorization/roleAssignments@2022-04-01"
      }
    }
    ignore_body_changes = {
      network_network_security_perimeters_profiles = {
        authorization_locks = ["properties.notes"]
      }
      network_network_security_perimeters_resource_associations = {
        authorization_role_assignments = ["properties.description"]
      }
    }
    profiles = {
      profile = {
        name = "profile"
        lock = { kind = "CanNotDelete", name = "profile-lock" }
        role_assignments = {
          reader = {
            name                       = "00000000-0000-0000-0000-000000000010"
            principal_id               = "00000000-0000-0000-0000-000000000011"
            role_definition_id_or_name = "Reader"
          }
        }
      }
    }
    access_rules = {
      rule = {
        name             = "rule", profile_key = "profile", direction = "Inbound"
        address_prefixes = ["203.0.113.0/24"]
        lock             = { kind = "CanNotDelete" }
      }
    }
    resource_associations = {
      storage = {
        name                     = "storage", profile_key = "profile"
        private_link_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/external"
        private_link_resource_extensions = {
          role_assignments = {
            reader = {
              name                       = "00000000-0000-0000-0000-000000000020"
              principal_id               = "00000000-0000-0000-0000-000000000011"
              role_definition_id_or_name = "Reader"
            }
          }
        }
      }
    }
    links = {
      remote = {
        name                                       = "remote"
        auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
        remote_perimeter_extensions = {
          lock = { kind = "CanNotDelete", name = "remote-lock", notes = "Explicit target override" }
        }
      }
    }
  }
  assert {
    condition     = output.profiles["profile"].extension_resource_ids.lock == "${output.resource_id}/profiles/profile/providers/Microsoft.Authorization/locks/profile-lock" && output.access_rules["rule"].extension_resource_ids.lock == "${output.resource_id}/profiles/profile/accessRules/rule/providers/Microsoft.Authorization/locks/lock-CanNotDelete"
    error_message = "Child extensions must be owned inside their submodules at stable child scopes."
  }
  assert {
    condition     = output.resource_associations["storage"].extension_resource_ids.private_link_resource.lock == "${var.resource_associations.storage.private_link_resource_id}/providers/Microsoft.Authorization/locks/primary-lock" && output.links["remote"].extension_resource_ids.remote_perimeter.lock == "${var.links.remote.auto_approved_remote_perimeter_resource_id}/providers/Microsoft.Authorization/locks/remote-lock"
    error_message = "External locks must inherit the perimeter lock or honor an explicit target override."
  }
  assert {
    condition     = output.resource_associations["storage"].extension_resource_ids.private_link_resource.role_assignments["reader"] == "${var.resource_associations.storage.private_link_resource_id}/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000020"
    error_message = "Root outputs must use the child's direct target assignment binding, not a removed wrapper address."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "repeated_remote_single_extension_owner" {
  command = apply
  override_resource {
    target = module.nsp_link["a"].azapi_resource.this
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-test/links/a"
    }
  }
  variables {
    lock = { kind = "CanNotDelete" }
    links = {
      a = {
        name                                       = "a"
        auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
      }
      b = {
        name                                       = "b"
        auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
        remote_perimeter_extensions                = { lock_inheritance_enabled = false, lock = { kind = "ReadOnly" } }
      }
    }
  }
  assert {
    condition     = output.links["a"].extension_resource_ids.remote_perimeter.lock != null && output.links["b"].extension_resource_ids.remote_perimeter.lock == null
    error_message = "Repeated references are allowed only with one lock owner; explicit disable wins over overrides."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "leaves_repeated_remote_lock_conflicts_to_azure" {
  command = plan
  variables {
    lock = { kind = "CanNotDelete" }
    links = {
      a = {
        name                                       = "a"
        auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
      }
      b = {
        name                                       = "b"
        auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/microsoft.network/networksecurityperimeters/REMOTE"
      }
    }
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "leaves_cross_path_lock_conflicts_to_azure" {
  command = plan
  variables {
    lock = { kind = "CanNotDelete" }
    links = {
      a = {
        name                                       = "a"
        auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
      }
    }
    link_references = {
      b = {
        name                         = "b"
        remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
      }
    }
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "reject_repeated_paas_association" {
  command = plan
  variables {
    profiles = { profile = { name = "profile" } }
    resource_associations = {
      a = {
        name                     = "a", profile_key = "profile"
        private_link_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/external"
      }
      b = {
        name                     = "b", profile_key = "profile"
        private_link_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/EXTERNAL"
      }
    }
  }
  expect_failures = [var.resource_associations]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "leaves_cross_path_role_alias_conflicts_to_azure" {
  command = plan
  variables {
    links = {
      a = {
        name                                       = "a"
        auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
        remote_perimeter_extensions = {
          role_assignments = {
            reader = {
              principal_id               = "00000000-0000-0000-0000-000000000011"
              role_definition_id_or_name = "Reader"
            }
          }
        }
      }
    }
    link_references = {
      b = {
        name                         = "b"
        remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
        remote_perimeter_extensions = {
          role_assignments = {
            reader = {
              principal_id               = "00000000-0000-0000-0000-000000000011"
              role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            }
          }
        }
      }
    }
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "child_lock_does_not_become_root_target_fallback" {
  command = apply
  override_resource {
    target = module.nsp_link["a"].azapi_resource.this
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/nsp-test/links/a"
    }
  }
  variables {
    links = {
      a = {
        name                                       = "a"
        lock                                       = { kind = "CanNotDelete", name = "child-only" }
        auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
      }
    }
  }
  assert {
    condition     = output.links["a"].extension_resource_ids.lock != null && output.links["a"].extension_resource_ids.remote_perimeter.lock == null
    error_message = "Root target inheritance must use the primary perimeter lock, never accidentally fall back to an item's own child lock."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "leaves_cross_path_contextual_role_aliases_to_azure" {
  command = plan
  variables {
    links = {
      a = {
        name                                       = "a"
        auto_approved_remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
        remote_perimeter_extensions = {
          role_assignments = {
            reader = {
              principal_id               = "00000000-0000-0000-0000-000000000011"
              role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            }
          }
        }
      }
    }
    link_references = {
      b = {
        name                         = "b"
        remote_perimeter_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/networkSecurityPerimeters/remote"
        remote_perimeter_extensions = {
          role_assignments = {
            reader = {
              principal_id               = "00000000-0000-0000-0000-000000000011"
              role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000099/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            }
          }
        }
      }
    }
  }
  providers = {
    azapi  = azapi
    random = random
  }
}
