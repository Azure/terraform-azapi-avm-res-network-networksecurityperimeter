variable "ignore_body_changes" {
  type = object({
    network_network_security_perimeters_resource_associations = optional(list(string), [])
    authorization_locks                                       = optional(list(string), [])
    authorization_role_assignments                            = optional(list(string), [])
  })
  default     = {}
  description = "Body-relative dot-notation paths: `network_network_security_perimeters_resource_associations` for the association; `authorization_locks` for child and target locks; `authorization_role_assignments` for child and target RBAC. Same ARM-kind resources share one field, applied uniformly to both scopes. Ignored configuration is not sent to Azure; changes take effect after apply. List indices are unsupported."
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_network_security_perimeters_resource_associations = optional(string, "Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2025-05-01")
    authorization_locks                                       = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments                            = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    authorization_role_definitions                            = optional(string, "Microsoft.Authorization/roleDefinitions@2022-04-01")
  })
  default     = {}
  description = "AzAPI types and tested API defaults owned here: `network_network_security_perimeters_resource_associations` for the association; `authorization_locks` for child and target locks; `authorization_role_assignments` for child and target RBAC; `authorization_role_definitions` for stable-scope lookups. Same ARM-kind resources share a uniform override."
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = "Retry settings: `error_message_regex` selects retryable errors; `interval_seconds` and `max_interval_seconds` control initial and maximum delay."
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
