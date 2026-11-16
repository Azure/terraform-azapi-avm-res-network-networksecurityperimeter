variable "name" {
  type        = string
  description = "The name of the link reference."
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
