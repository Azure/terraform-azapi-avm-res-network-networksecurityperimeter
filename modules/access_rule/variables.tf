variable "direction" {
  type        = string
  description = "Direction of the access rule. Possible values: `Inbound`, `Outbound`."

  validation {
    condition     = contains(["Inbound", "Outbound"], var.direction)
    error_message = "The direction must be one of: 'Inbound', 'Outbound'."
  }
}

variable "name" {
  type        = string
  description = "The name of the access rule. Must be 1-80 characters, start and end with alphanumeric, and may contain alphanumeric, underscore, period, or hyphen."

  validation {
    condition     = can(regex("(^[a-zA-Z0-9]+[a-zA-Z0-9_.\\-]*[a-zA-Z0-9]+$)|(^[a-zA-Z0-9]$)", var.name)) && length(var.name) <= 80
    error_message = "The name must be 1-80 characters long, start and end with an alphanumeric character, and may contain alphanumeric, underscore, period, or hyphen characters."
  }
}

variable "profile_resource_id" {
  type        = string
  description = "The resource ID of the parent NSP profile."
}

variable "address_prefixes" {
  type        = list(string)
  default     = []
  description = "List of inbound IPv4/IPv6 address prefixes. Applicable for `Inbound` rules."
}

variable "email_addresses" {
  type        = list(string)
  default     = []
  description = "List of outbound email addresses. Currently unavailable for use."
}

variable "fully_qualified_domain_names" {
  type        = list(string)
  default     = []
  description = "List of outbound FQDNs. Applicable for `Outbound` rules."
}

variable "phone_numbers" {
  type        = list(string)
  default     = []
  description = "List of outbound phone numbers. Currently unavailable for use."
}

variable "service_tags" {
  type        = list(string)
  default     = []
  description = "List of inbound service tag names. Currently unavailable for use."
}

variable "subscriptions" {
  type        = list(string)
  default     = []
  description = "List of subscription IDs (ARM format: `/subscriptions/{id}`) for cross-subscription inbound access."
}
