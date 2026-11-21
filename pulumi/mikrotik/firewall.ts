import * as routeros from "@pulumi/routeros";

// Rules are created in this order and kept in it on the router by MoveItems.
const filterRules: Record<string, Omit<routeros.IpFirewallFilterArgs, "comment"> & { comment: string }> = {
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
    "0135-accept-wireguard-remote": {
        chain: "input",
        action: "accept",
        srcAddress: "10.10.0.0/24",
        comment: "Allow WireGuard Remote Management",
    },
    "0140-accept-wgportal": {
        chain: "input",
        action: "accept",
        protocol: "udp",
        dstPort: "51821",
        comment: "wg-portal remote access",
    },
    "0150-accept-wireguard": {
        chain: "input",
        action: "accept",
        protocol: "udp",
        dstPort: "51820",
        comment: "WireGuard remote access",
    },
    "0999-drop-input": { chain: "input", action: "drop", comment: "Drop everything else" },
};

const natRules: Record<string, routeros.IpFirewallNatArgs> = {
    "0200-wireguard-clients-masquerade": {
        chain: "srcnat",
        action: "masquerade",
        srcAddress: "10.10.0.0/24",
        comment: "WireGuard clients masquerade",
    },
};

const filters = Object.entries(filterRules).map(
    ([key, rule]) => new routeros.IpFirewallFilter(`firewall-filter-${key}`, rule),
);

new routeros.MoveItems(
    "firewall-filter_rules",
    { resourcePath: "/ip/firewall/filter", sequences: filters.map((rule) => rule.id) },
    { dependsOn: filters },
);

const nats = Object.entries(natRules).map(([key, rule]) => new routeros.IpFirewallNat(`firewall-nat-${key}`, rule));

new routeros.MoveItems(
    "firewall-nat_rules",
    { resourcePath: "/ip/firewall/nat", sequences: nats.map((rule) => rule.id) },
    { dependsOn: nats },
);
