resource "routeros_ipv6_address" "lan_gua" {
  address   = "2a01:e0a:e4b:aa31::1/64"
  interface = "vlan10-mgmt"
  advertise = true
}

resource "routeros_ipv6_address" "wg_mb_gua" {
  address   = "2a01:e0a:e4b:aa31:ffff::1/128"
  interface = routeros_interface_wireguard.wg_mb.name
  advertise = false
}

resource "routeros_ipv6_address" "wg_mb_ll" {
  address   = "fe80::2/64"
  interface = routeros_interface_wireguard.wg_mb.name
}

# advertise_dns=false avoids dual-stack clients racing AAAA queries upstream and caching NXDOMAIN over private zones.
resource "routeros_ipv6_neighbor_discovery" "lan" {
  interface           = "vlan10-mgmt"
  advertise_dns       = false
  other_configuration = true
  ra_interval         = "20s-1m"
}

resource "routeros_ipv6_route" "default" {
  dst_address = "::/0"
  gateway     = "fe80::3a07:16ff:fec7:1815%vlan10-mgmt"
  comment     = "IPv6 default via Freebox"
}

resource "routeros_ipv6_firewall_filter" "input_wireguard" {
  chain    = "input"
  action   = "accept"
  protocol = "udp"
  dst_port = "51820"
  comment  = "WireGuard vx0"
}

resource "routeros_ipv6_firewall_filter" "input_established" {
  chain            = "input"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "Accept established"
}

resource "routeros_ipv6_firewall_filter" "input_icmpv6" {
  chain    = "input"
  action   = "accept"
  protocol = "icmpv6"
  comment  = "ICMPv6 mandatory"

  depends_on = [routeros_ipv6_firewall_filter.input_established]
}

resource "routeros_ipv6_firewall_filter" "forward_established" {
  chain            = "forward"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "Accept established"

  depends_on = [routeros_ipv6_firewall_filter.input_icmpv6]
}

resource "routeros_ipv6_firewall_filter" "forward_lan_to_wan" {
  chain        = "forward"
  action       = "accept"
  in_interface = "vlan10-mgmt"
  comment      = "LAN to WAN"

  depends_on = [routeros_ipv6_firewall_filter.forward_established]
}

resource "routeros_ipv6_firewall_filter" "input_lan_v6" {
  chain       = "input"
  action      = "accept"
  src_address = "2a01:e0a:e4b:aa31::/64"
  comment     = "Allow LAN IPv6"

  depends_on = [routeros_ipv6_firewall_filter.forward_lan_to_wan]
}

resource "routeros_ipv6_firewall_filter" "input_link_local" {
  chain       = "input"
  action      = "accept"
  src_address = "fe80::/10"
  comment     = "Allow link-local"

  depends_on = [routeros_ipv6_firewall_filter.input_lan_v6]
}

resource "routeros_ipv6_firewall_filter" "forward_vx0_to_lan" {
  chain        = "forward"
  action       = "accept"
  in_interface = routeros_interface_wireguard.wg_mb.name
  comment      = "vx0 to LAN"

  depends_on = [routeros_ipv6_firewall_filter.input_link_local]
}

resource "routeros_ipv6_firewall_filter" "forward_drop" {
  chain   = "forward"
  action  = "drop"
  comment = "Drop rest"

  depends_on = [routeros_ipv6_firewall_filter.forward_vx0_to_lan]
}
