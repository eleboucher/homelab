resource "routeros_ip_dns" "server" {
  allow_remote_requests = true
  servers               = ["1.1.1.1", "1.0.0.1", "9.9.9.9"]
  cache_size            = 20480
  cache_max_ttl         = "1d"

  max_concurrent_queries      = 500
  max_concurrent_tcp_sessions = 100

  query_server_timeout = "8s"
}

# ExternalDNS owns every *.erwanleboucher.dev record; only router-local entries here.
locals {
  static_dns_records = {
    "router.erwanleboucher.dev" = "192.168.1.2"
    "kharkiv.k8s.internal"      = "192.168.1.41"
    "le-havre.k8s.internal"     = "192.168.1.7"
    "normandie.internal"        = "192.168.1.40"
  }
}

resource "routeros_ip_dns_record" "static" {
  for_each = local.static_dns_records

  name    = each.key
  type    = "A"
  address = each.value
}
