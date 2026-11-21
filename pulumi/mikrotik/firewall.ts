import * as routeros from "@pulumi/routeros";

// Rules are created in this order and kept in it on the router by MoveItems.
const filterRules: Record<
  string,
  Omit<routeros.IpFirewallFilterArgs, "comment"> & { comment: string }
> = {
  "0100-accept-icmp": { chain: "input", action: "accept", protocol: "icmp", comment: "Allow Ping" },
  "0110-accept-established": {
    chain: "input",
    action: "accept",
    connectionState: "established,related",
    comment: "Allow Established",
  },
  // Pod traffic arrives masqueraded as node IPs; add 10.42.0.0/16 if that ever changes.
  "0120-accept-lan": {
    chain: "input",
    action: "accept",
    srcAddress: "192.168.1.0/24",
    comment: "Allow LAN Management",
  },
  "0130-accept-tailscale": {
    chain: "input",
    action: "accept",
    srcAddress: "192.168.69.0/24",
    comment: "Allow Tailscale Management",
  },
  "0999-drop-input": { chain: "input", action: "drop", comment: "Drop everything else" },
};

const filters = Object.entries(filterRules).map(
  ([key, rule]) => new routeros.IpFirewallFilter(`firewall-filter-${key}`, rule),
);

new routeros.MoveItems(
  "firewall-filter_rules",
  { resourcePath: "/ip/firewall/filter", sequences: filters.map((rule) => rule.id) },
  { dependsOn: filters },
);
