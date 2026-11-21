import * as unifi from "@pulumi/unifi";

// The gateway ships with this network: adopt it with `just unifi import-lan` before the first `up`.
export const lan = new unifi.Network("lan", {
  name: "Default",
  subnet: "192.168.1.1/24",
  domainName: "internal",
  multicastDns: true,
  dhcpServer: {
    enabled: true,
    start: "192.168.1.3",
    stop: "192.168.1.200",
    leasetime: "24h",
  },
  // The Freebox routes aa31::/64 to the gateway's WAN link-local (next hop set in
  // the Freebox UI), so the prefix is static here, not a DHCPv6 delegation.
  ipv6: {
    interfaceType: "static",
    staticSubnet: "2a01:e0a:e4b:aa31::1/64",
    ra: { enabled: true, priority: "high" },
  },
});
