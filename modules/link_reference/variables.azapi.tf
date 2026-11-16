variable "ignore_body_changes" {
  type = object({
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
  })
  default     = {}
  description = "Body-relative dot-notation paths: `authorization_locks` for reference and remote locks; `authorization_role_assignments` for reference and remote RBAC. Same ARM-kind resources share one field, applied uniformly to both scopes. Ignored configuration is not sent to Azure until removed; changes take effect after apply. No ignore interface is applied to the GET-only reference."
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_network_security_perimeters_link_references = optional(string, "Microsoft.Network/networkSecurityPerimeters/linkReferences@2025-05-01")
    authorization_locks                                 = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments                      = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    authorization_role_definitions                      = optional(string, "Microsoft.Authorization/roleDefinitions@2022-04-01")
  })
  default     = {}
  description = "AzAPI types and tested API defaults owned here: `network_network_security_perimeters_link_references` for the GET-only reference; `authorization_locks` for reference and remote locks; `authorization_role_assignments` for reference and remote RBAC; `authorization_role_definitions` for stable-scope lookups. Same ARM-kind resources share a uniform override."
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = "Extension retry controls: error_message_regex, interval_seconds, max_interval_seconds. The GET-only reference data source does not support this resource argument."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = "Extension Go-duration timeouts: create, read, update, delete. The GET-only reference data source has no resource timeouts block."
}
