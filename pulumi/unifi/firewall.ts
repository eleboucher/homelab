import * as unifi from "@pulumi/unifi";
import { lan } from "./network";

new unifi.Nat("lb_hairpin", {
  description: "Fix triangle routing to Cilium LB pool",
  type: "MASQUERADE",
  ipVersion: "IPV4",
  outInterface: lan.id,
  destinationFilter: { filterType: "ADDRESS_AND_PORT", address: "192.168.69.0/24" },
});

new unifi.Nat("lb_hairpin_v6", {
  description: "Fix triangle routing to Cilium LB pool (IPv6)",
  type: "MASQUERADE",
  ipVersion: "IPV6",
  ruleIndex: 1,
  outInterface: lan.id,
  sourceFilter: { filterType: "ADDRESS_AND_PORT", address: "2a01:e0a:e4b:aa31::/64" },
  destinationFilter: { filterType: "ADDRESS_AND_PORT", address: "2a01:e0a:e4b:aa32::/64" },
});
