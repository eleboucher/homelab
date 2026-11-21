import * as routeros from "@pulumi/routeros";

new routeros.Ipv6Address("lan_gua", {
  address: "2a01:e0a:e4b:aa31::2/64",
  interface: "vlan10-mgmt",
  advertise: false,
});

// The UCG sends the router advertisements for this LAN.
new routeros.Ipv6NeighborDiscovery("lan-nd", { interface: "vlan10-mgmt", disabled: true });

new routeros.Ipv6Route("default-route-v6", {
  dstAddress: "::/0",
  gateway: "2a01:e0a:e4b:aa31::1",
  comment: "IPv6 default via UCG",
});

// Created one after the other, in the order the router evaluates them.
const filterRules: [string, routeros.Ipv6FirewallFilterArgs][] = [
  [
    "input_established",
    {
      chain: "input",
      action: "accept",
      connectionState: "established,related,untracked",
      comment: "Accept established",
    },
  ],
  [
    "input_icmpv6",
    { chain: "input", action: "accept", protocol: "icmpv6", comment: "ICMPv6 mandatory" },
  ],
  [
    "forward_established",
    {
      chain: "forward",
      action: "accept",
      connectionState: "established,related,untracked",
      comment: "Accept established",
    },
  ],
  [
    "forward_lan_to_wan",
    {
      chain: "forward",
      action: "accept",
      inInterface: "vlan10-mgmt",
      srcAddress: "2a01:e0a:e4b:aa30::/60",
      comment: "LAN egress (our /60)",
    },
  ],
  [
    "input_lan_v6",
    {
      chain: "input",
      action: "accept",
      srcAddress: "2a01:e0a:e4b:aa31::/64",
      comment: "Allow LAN IPv6",
    },
  ],
  [
    "input_link_local",
    { chain: "input", action: "accept", srcAddress: "fe80::/10", comment: "Allow link-local" },
  ],
  [
    "forward_icmpv6",
    { chain: "forward", action: "accept", protocol: "icmpv6", comment: "ICMPv6 forward" },
  ],
  [
    "forward_lb_inbound_tcp",
    {
      chain: "forward",
      action: "accept",
      protocol: "tcp",
      dstAddress: "2a01:e0a:e4b:aa32::126/128",
      dstPort: "80,443,2222",
      comment: "Inbound TCP to external gateway VIP",
    },
  ],
  ["forward_drop", { chain: "forward", action: "drop", comment: "Drop rest" }],
];

const filters: routeros.Ipv6FirewallFilter[] = [];
for (const [name, rule] of filterRules) {
  filters.push(new routeros.Ipv6FirewallFilter(name, rule, { dependsOn: filters.slice(-1) }));
}

new routeros.MoveItems(
  "ipv6_filter_rules",
  { resourcePath: "/ipv6/firewall/filter", sequences: filters.map((rule) => rule.id) },
  { dependsOn: filters },
);
