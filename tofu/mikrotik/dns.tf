module "dns" {
  source = "git::https://github.com/mirceanton/terraform-modules-routeros.git//modules/dns-server?ref=v0.2.1"

  upstream_dns          = ["1.1.1.1", "1.0.0.1", "9.9.9.9"]
  allow_remote_requests = true
  cache_size            = 20480
  cache_max_ttl         = "1d"

  # ExternalDNS owns every *.erwanleboucher.dev record; only router-local entries here.
  static_dns = {
    "router.erwanleboucher.dev" = {
      type    = "A"
      address = "192.168.1.2"
    }
    "kharkiv.k8s.internal" = {
      type    = "A"
      address = "192.168.1.41"
    }
    "le-havre.k8s.internal" = {
      type    = "A"
      address = "192.168.1.7"
    }
    "normandie.internal" = {
      type    = "A"
      address = "192.168.1.40"
    }
  }
}
