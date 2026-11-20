# -------------------------------------------------------------------------
# NSP-specific variables
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# AVM required resource interfaces
# -------------------------------------------------------------------------


variable "location" {
  type        = string
  description = "Azure region where the resource should be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the Network Security Perimeter. Must be 1-80 characters, start and end with alphanumeric, and may contain alphanumeric, underscore, period, or hyphen."

  validation {
    condition     = can(regex("(^[a-zA-Z0-9]+[a-zA-Z0-9_.\\-]*[a-zA-Z0-9]+$)|(^[a-zA-Z0-9]$)", var.name)) && length(var.name) <= 80
    error_message = "The name must be 1-80 characters long, start and end with an alphanumeric character, and may contain alphanumeric, underscore, period, or hyphen characters."
  }
}

# This is required for most resource modules
variable "parent_id" {
  type        = string
  description = "The fully-qualified ARM resource ID of the existing resource group. This module does not create its parent scope."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid Azure resource group resource ID."
  }
}

variable "access_rules" {
  type = map(object({
    name                         = string
    profile_key                  = string
    direction                    = string
    address_prefixes             = optional(list(string), [])
    email_addresses              = optional(list(string), [])
    fully_qualified_domain_names = optional(list(string), [])
    phone_numbers                = optional(list(string), [])
    service_tags                 = optional(list(string), [])
    subscriptions                = optional(list(string), [])
    lock = optional(object({
      kind  = string
      name  = optional(string, null)
      notes = optional(string, null)
    }))
    role_assignments = optional(map(object({
      name                                   = optional(string, null)
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of NSP access rules to create. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `name` - (Required) The name of the access rule. Must follow NSP naming constraints (1-80 chars, alphanumeric with `_`, `.`, `-`).
- `profile_key` - (Required) The key from `var.profiles` that identifies the profile this rule belongs to.
- `direction` - (Required) Direction of the access rule. Possible values: `Inbound`, `Outbound`.
- `address_prefixes` - (Optional) List of inbound IPv4/IPv6 address prefixes. Applicable for `Inbound` rules.
- `email_addresses` - (Optional) List of outbound email addresses. Currently unavailable for use.
- `fully_qualified_domain_names` - (Optional) List of outbound FQDNs. Applicable for `Outbound` rules.
- `phone_numbers` - (Optional) List of outbound phone numbers. Currently unavailable for use.
- `service_tags` - (Optional) List of inbound service tag names. Currently unavailable for use.
- `subscriptions` - (Optional) List of subscription IDs (ARM format: `/subscriptions/{id}`) for cross-subscription inbound access.
- `lock` - (Optional) Canonical kind/name/notes lock on this access-rule scope; defaults absent.
- `role_assignments` - (Optional) Canonical RBAC name, role_definition_id_or_name, principal_id, description, skip_service_principal_aad_check, condition, condition_version, delegated_managed_identity_resource_id and principal_type fields. Defaults empty; assignments are owned inside the access-rule module.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.access_rules : contains(["Inbound", "Outbound"], v.direction)])
    error_message = "The direction must be one of: 'Inbound', 'Outbound'."
  }
  validation {
    condition     = alltrue([for _, v in var.access_rules : can(regex("(^[a-zA-Z0-9]+[a-zA-Z0-9_.\\-]*[a-zA-Z0-9]+$)|(^[a-zA-Z0-9]$)", v.name)) && length(v.name) <= 80])
    error_message = "All access rule names must be 1-80 characters, start and end with an alphanumeric character, and may contain alphanumeric, underscore, period, or hyphen."
  }
  validation {
    condition     = alltrue([for _, v in var.access_rules : contains(keys(var.profiles), v.profile_key)])
    error_message = "All access_rules[*].profile_key values must match a key defined in var.profiles."
  }
  validation {
    condition     = length(distinct([for rule in var.access_rules : lower("${rule.profile_key}/${rule.name}")])) == length(var.access_rules)
    error_message = "Access rule names must be unique within each profile."
  }
  validation {
    condition     = alltrue(flatten([for rule in var.access_rules : [for id in rule.subscriptions : can(provider::azapi::parse_resource_id("Microsoft.Resources/subscriptions", id))]]))
    error_message = "Each access rule subscription must be a fully-qualified subscription resource ID."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "link_references" {
  type = map(object({
    name                         = string
    remote_perimeter_resource_id = optional(string)
    lock = optional(object({
      kind  = string
      name  = optional(string, null)
      notes = optional(string, null)
    }))
    role_assignments = optional(map(object({
      name                                   = optional(string, null)
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
    remote_perimeter_extensions = optional(object({
      lock_inheritance_enabled = optional(bool, true)
      lock = optional(object({
        kind  = string
        name  = optional(string, null)
        notes = optional(string, null)
      }))
      role_assignments = optional(map(object({
        name                                   = optional(string, null)
        role_definition_id_or_name             = string
        principal_id                           = string
        description                            = optional(string, null)
        skip_service_principal_aad_check       = optional(bool, false)
        condition                              = optional(string, null)
        condition_version                      = optional(string, null)
        delegated_managed_identity_resource_id = optional(string, null)
        principal_type                         = optional(string, null)
      })), {})
    }), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of existing NSP link references to look up, not create or delete. Link references are automatically created on the remote NSP when an NSP link is established. The pinned API exposes GET/DELETE but no PUT lifecycle. The map key is deliberately arbitrary.

- `name` - (Required) The name of the link reference.
- `lock` and `role_assignments` - Optional canonical reference-scope extensions; never reference lifecycle ownership.
- `remote_perimeter_resource_id` - Known remote NSP ARM ID; checked against GET before remote extension writes.
- `remote_perimeter_extensions` - Target-scoped canonical lock/RBAC settings. lock_inheritance_enabled defaults true; false overrides every lock. Omitted target lock inherits the primary perimeter lock; explicit target lock replaces it. RBAC defaults empty.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for reference in var.link_references : reference.remote_perimeter_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/networkSecurityPerimeters", reference.remote_perimeter_resource_id))])
    error_message = "Each link reference remote perimeter must be a valid Network Security Perimeter resource ID, or null."
  }
  validation {
    condition     = length(distinct([for reference in var.link_references : lower(reference.name)])) == length(var.link_references)
    error_message = "Link reference names must be unique within the perimeter."
  }
}

variable "links" {
  type = map(object({
    name                                       = string
    auto_approved_remote_perimeter_resource_id = optional(string)
    description                                = optional(string)
    local_inbound_profiles                     = optional(list(string), [])
    remote_inbound_profiles                    = optional(list(string), [])
    lock = optional(object({
      kind  = string
      name  = optional(string, null)
      notes = optional(string, null)
    }))
    role_assignments = optional(map(object({
      name                                   = optional(string, null)
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
    remote_perimeter_extensions = optional(object({
      lock_inheritance_enabled = optional(bool, true)
      lock = optional(object({
        kind  = string
        name  = optional(string, null)
        notes = optional(string, null)
      }))
      role_assignments = optional(map(object({
        name                                   = optional(string, null)
        role_definition_id_or_name             = string
        principal_id                           = string
        description                            = optional(string, null)
        skip_service_principal_aad_check       = optional(bool, false)
        condition                              = optional(string, null)
        condition_version                      = optional(string, null)
        delegated_managed_identity_resource_id = optional(string, null)
        principal_type                         = optional(string, null)
      })), {})
    }), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of NSP links to create. Links connect two Network Security Perimeters to allow traffic between them. The map key is deliberately arbitrary.

- `name` - (Required) The name of the link. Must follow NSP naming constraints (1-80 chars, alphanumeric with `_`, `.`, `-`).
- `auto_approved_remote_perimeter_resource_id` - (Optional) The resource ID of the remote NSP to auto-approve the link for.
- `description` - (Optional) A message passed to the owner of the remote NSP link resource to request approval.
- `local_inbound_profiles` - (Optional) List of local inbound profile names to which inbound traffic is allowed. Use `['*']` to allow inbound to all profiles.
- `remote_inbound_profiles` - (Optional) List of remote inbound profile names to which inbound traffic is allowed on the remote NSP.
- `lock` and `role_assignments` - Optional canonical link-scope extensions; defaults null and empty.
- `remote_perimeter_extensions` - Target-scoped canonical lock/RBAC settings. lock_inheritance_enabled defaults true; false overrides every lock. Omitted target lock inherits the primary perimeter lock; explicit target lock replaces it. RBAC defaults empty. No remote target lifecycle or tags are owned.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.links : can(regex("(^[a-zA-Z0-9]+[a-zA-Z0-9_.\\-]*[a-zA-Z0-9]+$)|(^[a-zA-Z0-9]$)", v.name)) && length(v.name) <= 80])
    error_message = "All link names must be 1-80 characters, start and end with an alphanumeric character, and may contain alphanumeric, underscore, period, or hyphen."
  }
  validation {
    condition     = alltrue([for link in var.links : link.auto_approved_remote_perimeter_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/networkSecurityPerimeters", link.auto_approved_remote_perimeter_resource_id))])
    error_message = "Each link remote perimeter must be a valid Network Security Perimeter resource ID, or null."
  }
  validation {
    condition     = length(distinct([for link in var.links : lower(link.name)])) == length(var.links)
    error_message = "Link names must be unique within the perimeter."
  }
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
- `notes` - (Optional) Notes about the lock. This value maps to `Microsoft.Authorization/locks.properties.notes`.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "profiles" {
  type = map(object({
    name = string
    lock = optional(object({
      kind  = string
      name  = optional(string, null)
      notes = optional(string, null)
    }))
    role_assignments = optional(map(object({
      name                                   = optional(string, null)
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of NSP profiles to create under the Network Security Perimeter. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `name` - (Required) The name of the profile. Must follow NSP naming constraints (1-80 chars, alphanumeric with `_`, `.`, `-`).
- `lock` and `role_assignments` - Optional canonical profile-scope extensions owned inside the profile submodule; defaults null and empty. Profile locks must be removed in a staged apply before descendant teardown; ReadOnly profile locks must be applied after descendants exist.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.profiles : can(regex("(^[a-zA-Z0-9]+[a-zA-Z0-9_.\\-]*[a-zA-Z0-9]+$)|(^[a-zA-Z0-9]$)", v.name)) && length(v.name) <= 80])
    error_message = "All profile names must be 1-80 characters, start and end with an alphanumeric character, and may contain alphanumeric, underscore, period, or hyphen."
  }
  validation {
    condition     = length(distinct([for profile in var.profiles : lower(profile.name)])) == length(var.profiles)
    error_message = "Profile names must be unique within the perimeter."
  }
}

variable "resource_associations" {
  type = map(object({
    name                     = string
    private_link_resource_id = string
    profile_key              = string
    access_mode              = optional(string, "Learning")
    lock = optional(object({
      kind  = string
      name  = optional(string, null)
      notes = optional(string, null)
    }))
    role_assignments = optional(map(object({
      name                                   = optional(string, null)
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
    private_link_resource_extensions = optional(object({
      lock_inheritance_enabled = optional(bool, true)
      lock = optional(object({
        kind  = string
        name  = optional(string, null)
        notes = optional(string, null)
      }))
      role_assignments = optional(map(object({
        name                                   = optional(string, null)
        role_definition_id_or_name             = string
        principal_id                           = string
        description                            = optional(string, null)
        skip_service_principal_aad_check       = optional(bool, false)
        condition                              = optional(string, null)
        condition_version                      = optional(string, null)
        delegated_managed_identity_resource_id = optional(string, null)
        principal_type                         = optional(string, null)
      })), {})
    }), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of NSP resource associations to link PaaS resources to the Network Security Perimeter. The map key is deliberately arbitrary.

- `name` - (Required) The name of the resource association. Must follow NSP naming constraints.
- `private_link_resource_id` - (Required) The ARM resource ID of the PaaS resource to associate (must support Private Link).
- `profile_key` - (Required) The key from `var.profiles` that identifies the NSP profile to assign to this association.
- `access_mode` - (Optional) Access mode for the association. Possible values: `Learning`, `Enforced`, `Audit`. Defaults to `Learning`.
- `lock` and `role_assignments` - Optional canonical association-scope extensions; defaults null and empty.
- `private_link_resource_extensions` - Target-scoped canonical lock/RBAC settings. lock_inheritance_enabled defaults true; false overrides every lock. Omitted target lock inherits the primary perimeter lock; explicit target lock replaces it. RBAC defaults empty. PaaS configuration/tags/lifecycle remain externally owned.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.resource_associations : contains(["Learning", "Enforced", "Audit"], v.access_mode)])
    error_message = "The access_mode must be one of: 'Learning', 'Enforced', 'Audit'."
  }
  validation {
    condition     = alltrue([for _, v in var.resource_associations : can(regex("(^[a-zA-Z0-9]+[a-zA-Z0-9_.\\-]*[a-zA-Z0-9]+$)|(^[a-zA-Z0-9]$)", v.name)) && length(v.name) <= 80])
    error_message = "All resource association names must be 1-80 characters, start and end with an alphanumeric character, and may contain alphanumeric, underscore, period, or hyphen."
  }
  validation {
    condition     = alltrue([for _, v in var.resource_associations : contains(keys(var.profiles), v.profile_key)])
    error_message = "All resource_associations[*].profile_key values must match a key defined in var.profiles."
  }
  validation {
    condition     = length(distinct([for association in var.resource_associations : lower(association.name)])) == length(var.resource_associations)
    error_message = "Resource association names must be unique within the perimeter."
  }
  validation {
    condition     = length(distinct([for association in var.resource_associations : lower(trimsuffix(association.private_link_resource_id, "/"))])) == length(var.resource_associations)
    error_message = "Each PaaS target must have exactly one association owner in this perimeter."
  }
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on the network security perimeter. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the role assignment. If not set, a random UUID will be generated. Changing this forces the creation of a new resource.
- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.role_assignments :
      v.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", v.delegated_managed_identity_resource_id))
    ])
    error_message = "Each `role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or null."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}
