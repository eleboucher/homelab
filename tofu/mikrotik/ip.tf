resource "routeros_ip_route" "default" {
  dst_address = "0.0.0.0/0"
  gateway     = "192.168.1.254"
  comment     = "Upstream to Freebox"
}

resource "routeros_ip_upnp" "settings" {
  enabled = true
}
