variable "assignment_name" {
  type        = string
  default     = null
  description = "Optional explicit assignment GUID."
}

variable "dependency_revision" {
  type        = string
  default     = "pending"
  description = "Change only this input to defer module data reads."
}

variable "principal_id" {
  type        = string
  default     = "00000000-0000-0000-0000-000000000001"
  description = "Principal used on all nine assignment surfaces."
}

variable "role_selector" {
  type        = string
  default     = "Reader"
  description = "Configured role selector used on every assignment surface."
}

variable "scope_suffix" {
  type        = string
  default     = ""
  description = "Changes the actual parent/child/target scopes without changing instance keys."
}
