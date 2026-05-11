resource "routeros_system_certificate" "mikrotik_api" {
  name        = "mikrotik-api"
  common_name = "192.168.1.2"
  days_valid  = 3650
  key_size    = "2048"
  key_usage = [
    "digital-signature",
    "key-encipherment",
    "data-encipherment",
    "key-cert-sign",
    "crl-sign",
    "tls-server",
    "tls-client",
  ]
  trusted = true
}
