import * as unifi from "@pulumi/unifi";
import { requireEnv } from "./env";

// Peer on towonel's admin WireGuard, so the LAN reaches envoy-internal (10.42.43.1 on n1).
const towonel = new unifi.VpnClient("towonel", {
  name: "towonel",
  subnet: "10.42.43.11/24",
  pullDns: false,
  defaultRoute: false,
  wireguard: {
    dnsServers: ["1.1.1.1"],
    peer: {
      ip: "151.80.142.238",
      port: 51821,
      publicKey: "RitDj7pqTflMAPkhwDJjqa+GaJ6RF0yd5cJqzxbv8x0=",
    },
    privateKeyWo: requireEnv("TOWONEL_WG_PRIVATE_KEY"),
    privateKeyWoVersion: 1,
  },
});

new unifi.TrafficRoute("towonel_envoy_internal", {
  description: "towonel envoy-internal",
  networkId: towonel.id,
  killSwitchEnabled: true,
  destination: { ips: [{ address: "10.42.43.1/32" }] },
});
