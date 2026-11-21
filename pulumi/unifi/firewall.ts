import * as unifi from "@pulumi/unifi";
import { lan } from "./network";

const external = unifi.getFirewallZoneOutput({ name: "External" });
const internal = unifi.getFirewallZoneOutput({ name: "Internal" });

new unifi.FirewallPolicy("external_gateway_v6", {
  name: "Inbound TCP to external gateway VIP",
  action: "ALLOW",
  protocol: "tcp",
  ipVersion: "IPV6",
  createAllowRespond: true,
  source: { zoneId: external.id, matchingTarget: "ANY" },
  destination: {
    zoneId: internal.id,
    matchingTarget: "IP",
    ips: ["2a01:e0a:e4b:aa32::126"],
    portMatchingType: "SPECIFIC",
    port: "80,443,2222",
  },
});

// LAN clients reach the LoadBalancer VIPs through the gateway, but the nodes
// answer them directly on the shared L2. Masquerading keeps both directions on
// the gateway so its stateful firewall sees the whole flow.
new unifi.Nat("lb_hairpin", {
  description: "Fix triangle routing to Cilium LB pool",
  type: "MASQUERADE",
  ipVersion: "IPV4",
  outInterface: lan.id,
  destinationFilter: { filterType: "ADDRESS_AND_PORT", address: "192.168.69.0/24" },
});

// Same triangle on IPv6. Only LAN sources are masqueraded so inbound internet
// traffic to the external gateway keeps its real client address.
new unifi.Nat("lb_hairpin_v6", {
  description: "Fix triangle routing to Cilium LB pool (IPv6)",
  type: "MASQUERADE",
  ipVersion: "IPV6",
  // The controller rejects a second rule without an explicit, unique index.
  ruleIndex: 1,
  outInterface: lan.id,
  sourceFilter: { filterType: "ADDRESS_AND_PORT", address: "2a01:e0a:e4b:aa31::/64" },
  destinationFilter: { filterType: "ADDRESS_AND_PORT", address: "2a01:e0a:e4b:aa32::/64" },
});
