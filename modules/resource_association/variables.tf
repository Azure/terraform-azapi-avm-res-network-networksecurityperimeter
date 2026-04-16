variable "name" {
  type        = string
  description = "The name of the resource association. Must be 1-80 characters, start and end with alphanumeric, and may contain alphanumeric, underscore, period, or hyphen."

  validation {
    condition     = can(regex("(^[a-zA-Z0-9]+[a-zA-Z0-9_.\\-]*[a-zA-Z0-9]+$)|(^[a-zA-Z0-9]$)", var.name)) && length(var.name) <= 80
    error_message = "The name must be 1-80 characters long, start and end with an alphanumeric character, and may contain alphanumeric, underscore, period, or hyphen characters."
  }
}

variable "network_security_perimeter_resource_id" {
  type        = string
  description = "The resource ID of the parent Network Security Perimeter."
}

variable "private_link_resource_id" {
  type        = string
  description = "The ARM resource ID of the PaaS resource to associate (must support Private Link)."
}

variable "profile_resource_id" {
  type        = string
  description = "The resource ID of the NSP profile to assign to this association."
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
