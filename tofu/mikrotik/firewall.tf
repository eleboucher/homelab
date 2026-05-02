module "firewall" {
  source = "git::https://github.com/mirceanton/terraform-modules-routeros.git//modules/firewall?ref=v0.2.1"

  interface_lists = {
    WAN = {
      interfaces = ["sfp-sfpplus1"]
    }
  }

  filter_rules = {
    "accept-icmp" = {
      chain    = "input"
      action   = "accept"
      protocol = "icmp"
      comment  = "Allow Ping"
      order    = 100
    }
    "accept-established" = {
      chain            = "input"
      action           = "accept"
      connection_state = "established,related"
      comment          = "Allow Established"
      order            = 110
    }
    "accept-lan" = {
      chain       = "input"
      action      = "accept"
      src_address = "192.168.1.0/24"
      comment     = "Allow LAN Management"
      order       = 120
    }
    "accept-tailscale" = {
      chain       = "input"
      action      = "accept"
      src_address = "192.168.69.0/24"
      comment     = "Allow Tailscale Management"
      order       = 130
    }
    "accept-wgportal" = {
      chain    = "input"
      action   = "accept"
      protocol = "udp"
      dst_port = "51821"
      comment  = "wg-portal remote access"
      order    = 140
    }
    "accept-wireguard" = {
      chain    = "input"
      action   = "accept"
      protocol = "udp"
      dst_port = "51820"
      comment  = "WireGuard remote access"
      order    = 150
    }
    "drop-input" = {
      chain   = "input"
      action  = "drop"
      comment = "Drop everything else"
      order   = 999
    }
  }

  nat_rules = {
    "fix-triangle-routing" = {
      chain       = "srcnat"
      action      = "masquerade"
      dst_address = "192.168.69.0/24"
      comment     = "Fix Triangle Routing"
      order       = 100
    }
    "wireguard-clients-masquerade" = {
      chain       = "srcnat"
      action      = "masquerade"
      src_address = "10.10.0.0/24"
      comment     = "WireGuard clients masquerade"
      order       = 200
    }
  }
}
