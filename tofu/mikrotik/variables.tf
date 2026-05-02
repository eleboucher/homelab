variable "routeros_url" {
  type = string

  validation {
    condition     = can(regex("^https?://", var.routeros_url))
    error_message = "routeros_url must start with http:// or https://."
  }
}

variable "routeros_username" {
  type      = string
  sensitive = true
}

variable "routeros_password" {
  type      = string
  sensitive = true
}

variable "routeros_ca_path" {
  type    = string
  default = ""
}

variable "routeros_insecure" {
  type    = bool
  default = false
}

variable "user_password_admin" {
  type      = string
  sensitive = true
  default   = null
}

variable "user_password_mktxp_user" {
  type      = string
  sensitive = true
  default   = null
}

variable "user_password_wg_portal" {
  type      = string
  sensitive = true
  default   = null
}

variable "user_password_homepage" {
  type      = string
  sensitive = true
  default   = null
}

variable "user_password_external_dns" {
  type      = string
  sensitive = true
  default   = null
}

