resource "routeros_system_identity" "this" {
  name = "MikroTik"
}

resource "routeros_system_clock" "this" {
  time_zone_name       = "Europe/Paris"
  time_zone_autodetect = false
}

resource "routeros_system_ntp_client" "this" {
  enabled = true
  mode    = "unicast"
  servers = ["time.cloudflare.com"]
}
