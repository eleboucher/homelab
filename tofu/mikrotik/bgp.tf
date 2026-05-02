resource "routeros_routing_bgp_instance" "k8s" {
  name      = "k8s-instance"
  as        = 64513
  router_id = "192.168.1.2"
}

resource "routeros_routing_bgp_instance" "vx0" {
  name      = "vx0-instance"
  as        = 4200005000
  router_id = "192.168.1.2"
}

resource "routeros_routing_filter_rule" "k8s_in_accept" {
  chain = "k8s-in"
  rule  = "accept"
}

resource "routeros_routing_filter_rule" "vx0_import_accept_lo" {
  chain = "vx0-import"
  rule  = "if (dst in 10.222.0.0/16) { accept }"
}

resource "routeros_routing_filter_rule" "vx0_export_long_prefix_reject" {
  chain = "vx0-export"
  rule  = "if (dst-len > 28) { reject }"
}

resource "routeros_routing_filter_rule" "vx0_export_accept_lo" {
  chain = "vx0-export"
  rule  = "if (dst in 10.222.0.0/16) { accept }"
}

resource "routeros_routing_filter_rule" "bgp_in_cilium_accept_lb" {
  chain = "bgp-in-cilium"
  rule  = "if (dst in 10.222.5.0/28) { accept }"
}

resource "routeros_routing_filter_rule" "bgp_in_cilium_reject_lo" {
  chain = "bgp-in-cilium"
  rule  = "if (dst in 10.222.0.0/16) { reject } accept"
}

resource "routeros_routing_filter_rule" "bgp_out_cilium_reject_lo" {
  chain = "bgp-out-cilium"
  rule  = "if (dst in 10.222.0.0/16) { reject }"
}

resource "routeros_routing_filter_rule" "bgp_out_cilium_accept" {
  chain = "bgp-out-cilium"
  rule  = "accept"
}

resource "routeros_routing_filter_rule" "vx0_export_reject" {
  chain = "vx0-export"
  rule  = "reject"
}

resource "routeros_routing_filter_rule" "vx0_import_reject" {
  chain = "vx0-import"
  rule  = "reject"
}

resource "routeros_routing_bgp_connection" "kharkiv" {
  name          = "to-kharkiv"
  as            = "64513"
  instance      = routeros_routing_bgp_instance.k8s.name
  routing_table = "main"
  disabled      = false

  remote {
    address = "192.168.1.41"
    as      = "64514"
  }

  local {
    role = "ebgp"
  }

  input {
    filter = "bgp-in-cilium"
  }

  output {
    filter_chain = "bgp-out-cilium"
  }

  lifecycle {
    ignore_changes = [add_path_out, local, remote]
  }
}

resource "routeros_routing_bgp_connection" "le_havre" {
  name          = "to-le-havre"
  as            = "64513"
  instance      = routeros_routing_bgp_instance.k8s.name
  routing_table = "main"
  disabled      = false

  remote {
    address = "192.168.1.7"
    as      = "64514"
  }

  local {
    role = "ebgp"
  }

  input {
    filter = "bgp-in-cilium"
  }

  output {
    filter_chain = "bgp-out-cilium"
  }

  lifecycle {
    ignore_changes = [add_path_out, local, remote]
  }
}

resource "routeros_routing_bgp_connection" "mortebrume" {
  name             = "mortebrume"
  as               = "4200005000"
  instance         = routeros_routing_bgp_instance.vx0.name
  address_families = "ip,ipv6"
  disabled         = false

  remote {
    address = "fe80::1%wg-mb"
    as      = "4200007010"
  }

  local {
    role = "ebgp"
  }

  input {
    filter = "vx0-import"
  }

  output {
    filter_chain = "vx0-export"
    redistribute = "static,bgp"
  }

  depends_on = [routeros_interface_wireguard.wg_mb]

  lifecycle {
    ignore_changes = [add_path_out, local, remote]
  }
}
