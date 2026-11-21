import * as unifi from "@pulumi/unifi";

// Remote access, replacing wg-remote on the MikroTik. Peers are added per device
// with unifi.WireguardPeer.
export const wgRemote = new unifi.VpnServer("wg_remote", {
  name: "wg-remote",
  subnet: "10.10.0.1/24",
  wireguard: { port: 51821 },
  dns: { servers: ["192.168.1.1"] },
});
