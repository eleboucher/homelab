resource "routeros_ip_address" "lan_gateway" {
  address   = "192.168.1.2/24"
  network   = "192.168.1.0"
  interface = routeros_interface_vlan.vlans["mgmt"].name
  comment   = "LAN Gateway"
}

resource "routeros_ip_pool" "lan" {
  name    = "lan-pool"
  ranges  = ["192.168.1.3-192.168.1.200"]
  comment = "LAN Pool"
}

resource "routeros_ip_dhcp_server" "lan" {
  name                      = "server1"
  interface                 = routeros_interface_vlan.vlans["mgmt"].name
  address_pool              = routeros_ip_pool.lan.name
  lease_time                = "1d"
  dynamic_lease_identifiers = "client-mac"
  use_reconfigure           = true
  authoritative             = "yes"
  comment                   = "LAN DHCP"
}

resource "routeros_ip_dhcp_server_network" "lan" {
  address     = "192.168.1.0/24"
  gateway     = "192.168.1.2"
  dns_server  = ["192.168.1.2"]
  domain      = "internal"
  comment     = "LAN Network"
  dhcp_option = [routeros_ip_dhcp_server_option.domain_search_internal.name]
}

resource "routeros_ip_dhcp_server_option" "domain_search_internal" {
  name  = "domain-search-internal"
  code  = 119
  value = "0x08'internal'0x00"
}

locals {
  static_leases = {
    "192.168.1.41" = {
      mac        = "38:05:25:35:3B:9A"
      comment    = "Kharkiv Management"
      lease_time = "4w2d"
    }
    "192.168.1.153" = {
      mac        = "02:00:00:00:00:02"
      comment    = "home assistant kubevirt"
      lease_time = null
    }
    "192.168.1.7" = {
      mac        = "6C:1F:F7:6B:4C:04"
      comment    = "le-havre"
      lease_time = "4w2d"
    }
    "192.168.1.140" = {
      mac        = "D0:CF:13:0D:B2:D0"
      comment    = null
      lease_time = null
    }
  }
}

resource "routeros_ip_dhcp_server_lease" "static" {
  for_each = local.static_leases

  address     = each.key
  mac_address = each.value.mac
  server      = routeros_ip_dhcp_server.lan.name
  comment     = each.value.comment
  lease_time  = each.value.lease_time
}
