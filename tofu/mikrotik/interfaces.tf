resource "routeros_interface_bridge" "bridge1" {
  name           = "bridge1"
  vlan_filtering = true
  igmp_snooping  = true
  pvid           = 10
}

resource "routeros_interface_ethernet" "ethernet" {
  for_each = local.ethernet_interfaces

  factory_name = each.key
  name         = each.key
  comment      = each.value.comment
  l2mtu        = lookup(each.value, "l2mtu", null)
  mtu          = lookup(each.value, "mtu", null)
}

resource "routeros_interface_bonding" "bonds" {
  for_each = local.bond_interfaces

  name                 = each.key
  comment              = each.value.comment
  slaves               = each.value.slaves
  mode                 = each.value.mode
  transmit_hash_policy = each.value.transmit_hash_policy
  mtu                  = each.value.mtu
  lacp_rate            = "1sec"
}

resource "routeros_interface_vlan" "vlans" {
  for_each = local.vlans

  name      = each.value.name
  interface = routeros_interface_bridge.bridge1.name
  vlan_id   = each.value.vlan_id
  mtu       = each.value.mtu
}

locals {
  # Short bond label used in the bridge-port comment, matches what's on the device so import is drift-free.
  bond_short_labels = {
    bond-kharkiv  = "Kharkiv"
    bond-le-havre = "Le-Havre"
  }

  bridge_port_members = merge(
    {
      for k, v in local.ethernet_interfaces : k => {
        comment     = v.comment
        untagged    = lookup(v, "untagged", null)
        frame_types = "admit-only-untagged-and-priority-tagged"
      } if lookup(v, "bridge_port", true)
    },
    {
      for k, v in local.bond_interfaces : k => {
        comment     = "${local.bond_short_labels[k]} (VLAN ${[for vk, vv in local.vlans : vv.vlan_id if vv.name == v.untagged][0]} untagged)"
        untagged    = v.untagged
        frame_types = "admit-all"
      }
    }
  )
}

resource "routeros_interface_bridge_port" "ports" {
  for_each = local.bridge_port_members

  bridge      = routeros_interface_bridge.bridge1.name
  interface   = each.key
  comment     = each.value.comment
  frame_types = each.value.frame_types
  pvid = each.value.untagged != null ? (
    [for vk, vv in local.vlans : vv.vlan_id if vv.name == each.value.untagged][0]
  ) : 1

  depends_on = [
    routeros_interface_ethernet.ethernet,
    routeros_interface_bonding.bonds,
  ]

  lifecycle {
    ignore_changes = [multicast_router]
  }
}

resource "routeros_interface_bridge_vlan" "bridge_vlans" {
  for_each = local.vlans

  bridge   = routeros_interface_bridge.bridge1.name
  vlan_ids = [each.value.vlan_id]
  tagged   = [routeros_interface_bridge.bridge1.name]
  untagged = [
    for k, v in local.bridge_port_members : k if v.untagged == each.value.name
  ]

  depends_on = [routeros_interface_bridge_port.ports]
}
