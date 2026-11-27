variable "ignore_body_changes" {
  type = object({
    network_network_security_perimeters_profiles_access_rules = optional(list(string), [])
    authorization_locks                                       = optional(list(string), [])
    authorization_role_assignments                            = optional(list(string), [])
  })
  default     = {}
  description = "Body-relative dot-notation paths: `network_network_security_perimeters_profiles_access_rules` for the rule; `authorization_locks` for its lock; `authorization_role_assignments` for its RBAC. Ignored configuration is not sent to Azure; changes take effect after apply. List indices are unsupported."
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_network_security_perimeters_profiles_access_rules = optional(string, "Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2025-05-01")
    authorization_locks                                       = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments                            = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    authorization_role_definitions                            = optional(string, "Microsoft.Authorization/roleDefinitions@2022-04-01")
  })
  default     = {}
  description = "AzAPI types and tested API defaults owned here: `network_network_security_perimeters_profiles_access_rules` for the rule; `authorization_locks` for locks; `authorization_role_assignments` for RBAC; `authorization_role_definitions` for stable-scope role lookup."
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string), ["ScopeLocked", "PrincipalNotFound", "LinkedAuthorizationFailed"])
    interval_seconds     = optional(number, 15)
    max_interval_seconds = optional(number, 60)
  })
  default     = {}
  description = "Retry settings: `error_message_regex` defaults to ScopeLocked, PrincipalNotFound and LinkedAuthorizationFailed for lock propagation and RBAC replication; `interval_seconds` and `max_interval_seconds` default to 15 and 60. Patterns can be replaced, or set retry to null for provider defaults. Retries do not grant missing permissions."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = "Go duration timeouts: `create`, `read`, `update`, and `delete`. Null uses provider defaults."
}
