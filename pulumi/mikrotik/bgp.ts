import * as routeros from "@pulumi/routeros";
import { wgMb } from "./wireguard";

const k8s = new routeros.RoutingBgpInstance("k8s", {
  name: "k8s-instance",
  as: "64513",
  routerId: "192.168.1.2",
});
const vx0 = new routeros.RoutingBgpInstance("vx0", {
  name: "vx0-instance",
  as: "4200005000",
  routerId: "192.168.1.2",
});

const filterRules: [string, string, string][] = [
  ["k8s_in_accept", "k8s-in", "accept"],
  ["vx0_import_accept_lo", "vx0-import", "if (dst in 10.222.0.0/16) { accept }"],
  ["vx0_export_long_prefix_reject", "vx0-export", "if (dst-len > 28) { reject }"],
  ["vx0_export_accept_lo", "vx0-export", "if (dst in 10.222.0.0/16) { accept }"],
  ["bgp_in_cilium_accept_lb", "bgp-in-cilium", "if (dst in 10.222.5.0/28) { accept }"],
  ["bgp_in_cilium_accept_lb_v6", "bgp-in-cilium", "if (dst in 2a01:e0a:e4b:aa32::/64) { accept }"],
  ["bgp_in_cilium_reject_lo", "bgp-in-cilium", "if (dst in 10.222.0.0/16) { reject } accept"],
  ["bgp_in_cilium_reject_lo_v6", "bgp-in-cilium", "if (dst in fd42::/56) { reject }"],
  ["bgp_out_cilium_reject_lo", "bgp-out-cilium", "if (dst in 10.222.0.0/16) { reject }"],
  ["bgp_out_cilium_accept", "bgp-out-cilium", "accept"],
  ["vx0_export_reject", "vx0-export", "reject"],
  ["vx0_import_reject", "vx0-import", "reject"],
];

for (const [name, chain, rule] of filterRules) {
  new routeros.RoutingFilterRule(name, { chain, rule });
}

new routeros.RoutingBgpConnection(
  "kharkiv",
  {
    name: "to-kharkiv",
    as: "64513",
    instance: k8s.name,
    addressFamilies: "ip",
    routingTable: "main",
    disabled: false,
    remote: { address: "192.168.1.41", as: "64514" },
    local: { role: "ebgp" },
    input: { filter: "bgp-in-cilium" },
    output: { filterChain: "bgp-out-cilium" },
  },
  { ignoreChanges: ["local", "remote"] },
);

new routeros.RoutingBgpConnection(
  "paris",
  {
    name: "to-paris",
    as: "64513",
    instance: k8s.name,
    addressFamilies: "ip",
    routingTable: "main",
    disabled: false,
    remote: { address: "192.168.1.42", as: "64514" },
    local: { role: "ebgp" },
    input: { filter: "bgp-in-cilium" },
    output: { filterChain: "bgp-out-cilium" },
  },
  { ignoreChanges: ["local", "remote"] },
);

new routeros.RoutingBgpConnection(
  "mortebrume",
  {
    name: "mortebrume",
    as: "4200005000",
    instance: vx0.name,
    addressFamilies: "ip,ipv6",
    disabled: false,
    remote: { address: "fe80::1%wg-mb", as: "4200007010" },
    local: { role: "ebgp" },
    input: { filter: "vx0-import" },
    output: { filterChain: "vx0-export", redistribute: "static,bgp" },
  },
  { dependsOn: [wgMb], ignoreChanges: ["local", "remote"] },
);
