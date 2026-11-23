import * as unifi from "@pulumi/unifi";
import { requireEnv } from "./env";

const qbittorrentIp = "192.168.100.10";

const forwardedPort = process.env.AIRVPN_PORT;
if (!forwardedPort) throw new Error("AIRVPN_PORT is not set");

export const torrent = new unifi.Network("torrent", {
  name: "Torrent",
  subnet: "192.168.100.1/24",
  vlan: 100,
  multicastDns: false,
  dhcpServer: {
    enabled: true,
    start: "192.168.100.100",
    stop: "192.168.100.200",
    leasetime: "24h",
  },
  ipv6: { interfaceType: "none" },
});

const wireguardConf = requireEnv("AIRVPN_WG_CONF");

const airvpn = new unifi.VpnClient("airvpn", {
  name: "AirVPN",
  subnet: requireEnv("AIRVPN_WG_ADDRESS"),
  pullDns: false,
  defaultRoute: false,
  wireguard: {
    configuration: {
      filename: "airvpn.conf",
      content: wireguardConf.apply((conf) => Buffer.from(conf).toString("base64")),
    },
    privateKeyWo: wireguardConf.apply((conf) => {
      const key = conf.match(/^PrivateKey\s*=\s*(\S+)/m)?.[1];
      if (!key) throw new Error("AIRVPN_WG_CONF has no PrivateKey line");
      return key;
    }),
    privateKeyWoVersion: 1,
  },
}, { dependsOn: torrent });

new unifi.TrafficRoute("torrent_via_airvpn", {
  description: "Torrent VLAN through AirVPN",
  networkId: airvpn.id,
  killSwitchEnabled: true,
  source: { networks: [{ id: torrent.id }] },
});

new unifi.Nat("airvpn_forward", {
  description: "AirVPN forwarded port to qBittorrent",
  type: "DNAT",
  ipVersion: "IPV4",
  ruleIndex: 2,
  protocol: "tcp_udp",
  inInterface: airvpn.id,
  destinationFilter: { filterType: "ADDRESS_AND_PORT", port: forwardedPort },
  ipAddress: qbittorrentIp,
  port: forwardedPort,
});

const zone = new unifi.FirewallZone("torrent", { name: "Torrent", networkIds: [torrent.id] });
const external = unifi.getFirewallZoneOutput({ name: "External" });
const internal = unifi.getFirewallZoneOutput({ name: "Internal" });

new unifi.FirewallPolicy("airvpn_to_qbittorrent", {
  name: "AirVPN forwarded port to qBittorrent",
  action: "ALLOW",
  protocol: "tcp_udp",
  ipVersion: "IPV4",
  source: { zoneId: external.id, matchingTarget: "ANY" },
  destination: {
    zoneId: zone.id,
    matchingTarget: "IP",
    ips: [qbittorrentIp],
    portMatchingType: "SPECIFIC",
    port: forwardedPort,
  },
});

new unifi.FirewallPolicy("block_torrent_to_lan", {
  name: "Block Torrent to LAN",
  action: "BLOCK",
  protocol: "all",
  ipVersion: "BOTH",
  source: { zoneId: zone.id, matchingTarget: "ANY" },
  destination: { zoneId: internal.id, matchingTarget: "ANY" },
});
