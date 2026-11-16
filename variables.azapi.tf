variable "ignore_body_changes" {
  type = object({
    network_network_security_perimeters = optional(list(string), [])
    authorization_locks                 = optional(list(string), [])
    authorization_role_assignments      = optional(list(string), [])
    network_network_security_perimeters_profiles = optional(object({
      network_network_security_perimeters_profiles = optional(list(string), [])
      authorization_locks                          = optional(list(string), [])
      authorization_role_assignments               = optional(list(string), [])
    }), {})
    network_network_security_perimeters_profiles_access_rules = optional(object({
      network_network_security_perimeters_profiles_access_rules = optional(list(string), [])
      authorization_locks                                       = optional(list(string), [])
      authorization_role_assignments                            = optional(list(string), [])
    }), {})
    network_network_security_perimeters_resource_associations = optional(object({
      network_network_security_perimeters_resource_associations = optional(list(string), [])
      authorization_locks                                       = optional(list(string), [])
      authorization_role_assignments                            = optional(list(string), [])
    }), {})
    network_network_security_perimeters_links = optional(object({
      network_network_security_perimeters_links = optional(list(string), [])
      authorization_locks                       = optional(list(string), [])
      authorization_role_assignments            = optional(list(string), [])
    }), {})
    network_network_security_perimeters_link_references = optional(object({
      authorization_locks            = optional(list(string), [])
      authorization_role_assignments = optional(list(string), [])
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative dot-notation paths to ignore. Individual list indices are unsupported. Ignored configuration is not sent to Azure until the path is removed. Changes take effect only after apply; removing a path can require a subsequent plan.

- `network_network_security_perimeters` - Perimeter paths.
- `authorization_locks` - Lock paths.
- `authorization_role_assignments` - Role assignment paths.
- `network_network_security_perimeters_profiles.network_network_security_perimeters_profiles` - Profile paths.
- `network_network_security_perimeters_profiles_access_rules.network_network_security_perimeters_profiles_access_rules` - Access rule paths.
- `network_network_security_perimeters_resource_associations.network_network_security_perimeters_resource_associations` - Association paths.
- `network_network_security_perimeters_links.network_network_security_perimeters_links` - Link paths.
- `network_network_security_perimeters_link_references` - GET-only references have no own-body ignore argument.
- Each child slot contains direct `authorization_locks` and `authorization_role_assignments` path lists for the resources owned by that child. Association, link and reference children apply each ARM-kind list uniformly to their distinct child and target resources. No root-body paths are reused for children.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_network_security_perimeters = optional(string, "Microsoft.Network/networkSecurityPerimeters@2025-05-01")
    authorization_locks                 = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments      = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    authorization_role_definitions      = optional(string, "Microsoft.Authorization/roleDefinitions@2022-04-01")
    network_network_security_perimeters_profiles = optional(object({
      network_network_security_perimeters_profiles = optional(string)
      authorization_locks                          = optional(string)
      authorization_role_assignments               = optional(string)
      authorization_role_definitions               = optional(string)
    }), {})
    network_network_security_perimeters_profiles_access_rules = optional(object({
      network_network_security_perimeters_profiles_access_rules = optional(string)
      authorization_locks                                       = optional(string)
      authorization_role_assignments                            = optional(string)
      authorization_role_definitions                            = optional(string)
    }), {})
    network_network_security_perimeters_resource_associations = optional(object({
      network_network_security_perimeters_resource_associations = optional(string)
      authorization_locks                                       = optional(string)
      authorization_role_assignments                            = optional(string)
      authorization_role_definitions                            = optional(string)
    }), {})
    network_network_security_perimeters_links = optional(object({
      network_network_security_perimeters_links = optional(string)
      authorization_locks                       = optional(string)
      authorization_role_assignments            = optional(string)
      authorization_role_definitions            = optional(string)
    }), {})
    network_network_security_perimeters_link_references = optional(object({
      network_network_security_perimeters_link_references = optional(string)
      authorization_locks                                 = optional(string)
      authorization_role_assignments                      = optional(string)
      authorization_role_definitions                      = optional(string)
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions. Defaults belong to the owning module.

- `network_network_security_perimeters` - Perimeter resource.
- `authorization_locks` - Management lock.
- `authorization_role_assignments` - Perimeter role assignments.
- `authorization_role_definitions` - Role definition lookup.
- `network_network_security_perimeters_profiles.network_network_security_perimeters_profiles` - Profile submodule override.
- `network_network_security_perimeters_profiles_access_rules.network_network_security_perimeters_profiles_access_rules` - Access rule submodule override.
- `network_network_security_perimeters_resource_associations.network_network_security_perimeters_resource_associations` - Association submodule override.
- `network_network_security_perimeters_links.network_network_security_perimeters_links` - Link submodule override.
- `network_network_security_perimeters_link_references.network_network_security_perimeters_link_references` - Link-reference GET API override.
- Each child slot contains direct `authorization_locks`, `authorization_role_assignments`, and `authorization_role_definitions` overrides for that child's extension resources and lookups. Same ARM-kind resources share a uniform override within the child, including its target resources. Children own the stable tested defaults; root slots do not repeat them.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string), ["ScopeLocked"])
    interval_seconds     = optional(number, 15)
    max_interval_seconds = optional(number, 60)
  })
  default     = {}
  description = <<DESCRIPTION
Retry configuration for supported AzAPI resources and child modules. The default retries ScopeLocked errors during lock-removal propagation, not update-time unlocking. Set null to use provider defaults.

- `error_message_regex` - Retryable error patterns.
- `interval_seconds` - Initial retry interval in seconds.
- `max_interval_seconds` - Maximum retry interval in seconds.
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Operation timeouts for supported AzAPI resources, cascaded unchanged to children. Defaults to null (provider defaults).

- `create` - Create timeout as a Go duration.
- `read` - Read timeout as a Go duration.
- `update` - Update timeout as a Go duration.
- `delete` - Delete timeout as a Go duration.
DESCRIPTION
}
