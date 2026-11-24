import * as unifi from "@pulumi/unifi";
import { requireEnv } from "./env";

export const iot = new unifi.Network("iot", {
  name: "IoT",
  subnet: "192.168.20.1/24",
  vlan: 20,
  multicastDns: true,
  dhcpServer: {
    enabled: true,
    start: "192.168.20.10",
    stop: "192.168.20.250",
    leasetime: "24h",
  },
  ipv6: { interfaceType: "none" },
});

new unifi.Client(
  "fixed-192.168.20.140",
  { mac: "d0:cf:13:0d:b2:d0", fixedIp: "192.168.20.140" },
  { dependsOn: iot },
);

new unifi.Client(
  "iot-9a77ee00193c",
  { mac: "9a:77:ee:00:19:3c", networkId: iot.id },
  { dependsOn: iot },
);

const zone = new unifi.FirewallZone("iot", { name: "IoT", networkIds: [iot.id] });
const internal = unifi.getFirewallZoneOutput({ name: "Internal" });
const gateway = unifi.getFirewallZoneOutput({ name: "Gateway" });
const external = unifi.getFirewallZoneOutput({ name: "External" });

new unifi.FirewallPolicy("lan_to_iot", {
  name: "LAN to IoT",
  action: "ALLOW",
  protocol: "all",
  ipVersion: "BOTH",
  createAllowRespond: true,
  source: { zoneId: internal.id, matchingTarget: "ANY" },
  destination: { zoneId: zone.id, matchingTarget: "ANY" },
});

const mqtt = new unifi.FirewallPolicy("iot_mqtt", {
  name: "IoT to MQTT and Frigate RTMP",
  action: "ALLOW",
  protocol: "tcp",
  ipVersion: "IPV4",
  source: { zoneId: zone.id, matchingTarget: "ANY" },
  destination: {
    zoneId: internal.id,
    matchingTarget: "IP",
    ips: ["192.168.69.122", "192.168.69.123"],
    portMatchingType: "SPECIFIC",
    port: "1883,1935",
  },
});

new unifi.FirewallPolicy(
  "block_iot_to_lan",
  {
    name: "Block IoT to LAN",
    action: "BLOCK",
    protocol: "all",
    ipVersion: "BOTH",
    source: { zoneId: zone.id, matchingTarget: "ANY" },
    destination: { zoneId: internal.id, matchingTarget: "ANY" },
  },
  { dependsOn: mqtt },
);

new unifi.FirewallPolicy("iot_to_gateway", {
  name: "IoT DNS, NTP and mDNS",
  action: "ALLOW",
  protocol: "tcp_udp",
  ipVersion: "IPV4",
  source: { zoneId: zone.id, matchingTarget: "ANY" },
  destination: {
    zoneId: gateway.id,
    matchingTarget: "ANY",
    portMatchingType: "SPECIFIC",
    port: "53,123,5353",
  },
});

new unifi.Nat("iot_dns_redirect", {
  description: "Redirect IoT DNS to gateway",
  type: "DNAT",
  ipVersion: "IPV4",
  protocol: "tcp_udp",
  inInterface: iot.id,
  destinationFilter: {
    filterType: "ADDRESS_AND_PORT",
    address: "192.168.20.1",
    invertAddress: true,
    port: "53",
  },
  ipAddress: "192.168.20.1",
  port: "53",
});

new unifi.FirewallPolicy("block_iot_dot", {
  name: "Block IoT DNS-over-TLS",
  action: "BLOCK",
  protocol: "tcp_udp",
  ipVersion: "IPV4",
  source: { zoneId: zone.id, matchingTarget: "ANY" },
  destination: {
    zoneId: external.id,
    matchingTarget: "ANY",
    portMatchingType: "SPECIFIC",
    port: "853",
  },
});

const apGroup = unifi.getApGroupOutput({ name: "All APs" });
const clientGroup = unifi.getClientQosRateOutput({ name: "Default" });

new unifi.Wlan("iot", {
  name: requireEnv("WIFI_SSID").apply((ssid) => `${ssid}-IoT`),
  security: "wpapsk",
  wpa3: { support: false, transition: false },
  pmfMode: "disabled",
  wlanBands: ["2g", "5g"],
  passphraseWo: requireEnv("WIFI_IOT_PASSWORD"),
  passphraseWoVersion: 1,
  networkId: iot.id,
  userGroupId: clientGroup.id,
  apGroup: { ids: [apGroup.id] },
});
