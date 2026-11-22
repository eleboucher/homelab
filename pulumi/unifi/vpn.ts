import * as unifi from "@pulumi/unifi";

export const wgHome = new unifi.VpnServer("wg_home", {
  name: "Home",
  subnet: "192.168.3.1/24",
  wireguard: { port: 51820 },
});

new unifi.WireguardPeer("wg_home-phone", {
  networkId: wgHome.id,
  name: "Phone",
  interfaceIp: "192.168.3.2",
  publicKey: "fueMW94V19eBEfLdpVuVsFKjn1NHycHXVWOYfgx2DzQ=",
  allowedIps: [],
});
