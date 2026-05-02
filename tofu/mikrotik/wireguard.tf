resource "routeros_interface_wireguard" "wg_mb" {
  name        = "wg-mb"
  listen_port = 51820
  mtu         = 1420

  lifecycle {
    ignore_changes = [private_key]
  }
}

resource "routeros_interface_wireguard_peer" "wg_mb_mortebrume" {
  name             = "peer1"
  interface        = routeros_interface_wireguard.wg_mb.name
  public_key       = local.wireguard_peer_public_keys["peer1"]
  endpoint_address = "2a01:4f8:242:4691:ffff::1"
  endpoint_port    = 51771
  allowed_address  = ["10.222.0.0/16", "fd4d:ac20:c274::/48", "fe80::1/128"]
}

resource "routeros_interface_wireguard" "wg_remote" {
  name        = "wg-remote"
  listen_port = 51821
  mtu         = 1420

  lifecycle {
    ignore_changes = [private_key]
  }
}

resource "routeros_ip_address" "wg_remote" {
  address   = "10.10.0.1/24"
  interface = routeros_interface_wireguard.wg_remote.name
  network   = "10.10.0.0"
}
