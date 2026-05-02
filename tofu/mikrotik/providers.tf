provider "routeros" {
  hosturl        = var.routeros_url
  username       = var.routeros_username
  password       = var.routeros_password
  ca_certificate = var.routeros_ca_path != "" ? var.routeros_ca_path : null
  insecure       = var.routeros_insecure
}
