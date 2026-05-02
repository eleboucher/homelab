locals {
  wireguard_peer_public_keys = {
    peer1 = "w/cHbGqlFMFdcNxaqT5BvRV3nMpm9J3gx5T/WIMhcxY="
  }

  vlans = {
    mgmt = {
      name    = "vlan10-mgmt"
      vlan_id = 10
      mtu     = 1500
    }
  }

  ethernet_interfaces = {
    ether1 = {
      comment     = "bond-kharkiv member"
      bridge_port = false
      l2mtu       = 9216
      mtu         = 9000
    }
    ether2 = {
      comment     = "bond-le-havre member"
      bridge_port = false
      l2mtu       = 9216
      mtu         = 9000
    }
    ether3 = {
      comment     = "bond-kharkiv member"
      bridge_port = false
      l2mtu       = 9216
      mtu         = 9000
    }
    ether4 = {
      comment     = "bond-le-havre member"
      bridge_port = false
      l2mtu       = 9216
      mtu         = 9000
    }
    ether5 = {
      comment  = "Access port"
      untagged = "vlan10-mgmt"
    }
    ether6 = {
      comment  = "Access port"
      untagged = "vlan10-mgmt"
    }
    ether7 = {
      comment  = "Access port"
      untagged = "vlan10-mgmt"
    }
    ether8 = {
      comment  = "Access port"
      untagged = "vlan10-mgmt"
    }
    sfp-sfpplus1 = {
      comment  = "WAN uplink"
      untagged = "vlan10-mgmt"
    }
    sfp-sfpplus2 = {
      comment  = "Access port"
      l2mtu    = 9216
      mtu      = 9000
      untagged = "vlan10-mgmt"
    }
  }

  bond_interfaces = {
    bond-kharkiv = {
      comment              = "Kharkiv LACP (Management + Storage)"
      slaves               = ["ether1", "ether3"]
      mode                 = "802.3ad"
      transmit_hash_policy = "layer-3-and-4"
      mtu                  = 9000
      untagged             = "vlan10-mgmt"
    }
    bond-le-havre = {
      comment              = "Le-Havre LACP (Management + Storage)"
      slaves               = ["ether2", "ether4"]
      mode                 = "802.3ad"
      transmit_hash_policy = "layer-3-and-4"
      mtu                  = 9000
      untagged             = "vlan10-mgmt"
    }
  }

  user_groups = {
    mktxp_group = {
      policies = ["read", "api", "rest-api", "!local", "!telnet", "!ssh", "!ftp", "!reboot", "!write", "!policy", "!test", "!winbox", "!password", "!web", "!sniff", "!sensitive", "!romon"]
    }
    homepage = {
      policies = ["read", "api", "rest-api", "!local", "!telnet", "!ssh", "!ftp", "!reboot", "!write", "!policy", "!test", "!winbox", "!password", "!web", "!sniff", "!sensitive", "!romon"]
    }
    wg-portal = {
      policies = ["read", "write", "sensitive", "api", "rest-api", "!local", "!telnet", "!ssh", "!ftp", "!reboot", "!policy", "!test", "!winbox", "!password", "!web", "!sniff", "!romon"]
    }
    external_dns = {
      policies = ["read", "write", "api", "rest-api", "!local", "!telnet", "!ssh", "!ftp", "!reboot", "!policy", "!test", "!winbox", "!password", "!web", "!sniff", "!sensitive", "!romon"]
    }
  }

  users = {
    admin = {
      group = "full"
    }
    mktxp_user = {
      group = "mktxp_group"
    }
    wg-portal = {
      group   = "wg-portal"
      address = "192.168.1.0/24,10.42.0.0/16"
    }
    homepage = {
      group = "homepage"
    }
    external-dns = {
      group = "external_dns"
    }
  }
}
