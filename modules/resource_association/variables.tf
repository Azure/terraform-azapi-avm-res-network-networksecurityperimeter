variable "name" {
  type        = string
  description = "The name of the resource association. Must be 1-80 characters, start and end with alphanumeric, and may contain alphanumeric, underscore, period, or hyphen."

  validation {
    condition     = can(regex("(^[a-zA-Z0-9]+[a-zA-Z0-9_.\\-]*[a-zA-Z0-9]+$)|(^[a-zA-Z0-9]$)", var.name)) && length(var.name) <= 80
    error_message = "The name must be 1-80 characters long, start and end with an alphanumeric character, and may contain alphanumeric, underscore, period, or hyphen characters."
  }
}

variable "parent_id" {
  type        = string
  description = "The resource ID of the parent Network Security Perimeter."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/networkSecurityPerimeters", var.parent_id))
    error_message = "`parent_id` must be a valid Network Security Perimeter resource ID."
  }
}

variable "private_link_resource_id" {
  type        = string
  description = "The fully-qualified ARM resource ID of the PaaS resource to associate (must support Private Link). Changing this immutable target deletes and recreates the association and its owned association-scope extensions, not the PaaS resource. Polymorphic resource types are deliberately not restricted to one parse_resource_id type under TFNFR38."
}

variable "profile_resource_id" {
  type        = string
  description = "The resource ID of the NSP profile to assign to this association."

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/networkSecurityPerimeters/profiles", var.profile_resource_id))
    error_message = "`profile_resource_id` must be a valid NSP profile resource ID."
  }
}

variable "access_mode" {
  type        = string
  default     = "Learning"
  description = "Access mode for the association. Possible values: `Learning`, `Enforced`, `Audit`. Defaults to `Learning`."

  validation {
    condition     = contains(["Learning", "Enforced", "Audit"], var.access_mode)
    error_message = "The access_mode must be one of: 'Learning', 'Enforced', 'Audit'."
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

variable "location" {
  type        = string
  default     = null
  description = "The Azure region for this module's resources or telemetry deployment."

  validation {
    condition     = !var.enable_telemetry || var.location != null
    error_message = "The location must not be null when telemetry is enabled."
  }
}
