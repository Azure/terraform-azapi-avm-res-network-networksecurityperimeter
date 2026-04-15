variable "name" {
  type        = string
  description = "The name of the NSP link. Must be 1-80 characters, start and end with alphanumeric, and may contain alphanumeric, underscore, period, or hyphen."

  validation {
    condition     = can(regex("(^[a-zA-Z0-9]+[a-zA-Z0-9_.\\-]*[a-zA-Z0-9]+$)|(^[a-zA-Z0-9]$)", var.name)) && length(var.name) <= 80
    error_message = "The name must be 1-80 characters long, start and end with an alphanumeric character, and may contain alphanumeric, underscore, period, or hyphen characters."
  }
}

variable "network_security_perimeter_resource_id" {
  type        = string
  description = "The resource ID of the parent Network Security Perimeter."
}

variable "auto_approved_remote_perimeter_resource_id" {
  type        = string
  default     = null
  description = "The resource ID of the remote NSP to auto-approve the link for."
}

variable "description" {
  type        = string
  default     = null
  description = "A message passed to the owner of the remote NSP link resource to request approval."
}

variable "local_inbound_profiles" {
  type        = list(string)
  default     = []
  description = "List of local inbound profile names to which inbound traffic is allowed. Use `['*']` to allow inbound to all profiles."
}

variable "remote_inbound_profiles" {
  type        = list(string)
  default     = []
  description = "List of remote inbound profile names to which inbound traffic is allowed. Use `['*']` to allow inbound to all profiles on the remote NSP."
}
