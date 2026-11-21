import * as unifi from "@pulumi/unifi";

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
  ipv6: {
    interfaceType: "static",
    staticSubnet: "2a01:e0a:e4b:aa31::1/64",
    ra: { enabled: true, priority: "high" },
  },
});
