import * as unifi from "@pulumi/unifi";
import { requireEnv } from "./env";

export const wgRemote = new unifi.VpnServer("wg_remote", {
  name: "wg-remote",
  subnet: "10.10.0.1/24",
  wireguard: {
    port: 51821,
    privateKeyWo: requireEnv("WG_REMOTE_PRIVATE_KEY"),
    privateKeyWoVersion: 1,
  },
  dns: { servers: ["192.168.1.1"] },
});

const remotePeers: Record<string, { interfaceIp: string; publicKey: string }> = {
  laptop: { interfaceIp: "10.10.0.2", publicKey: "5amT4B54fPrq3WeMrA08DcqJfnHjuePZuh7cLCYd/0A=" },
  "work-laptop": {
    interfaceIp: "10.10.0.3",
    publicKey: "sdMcT7cCQ/GZIDMCKXhVj+WQHRmGdRW34Whyzxz27H4=",
  },
};

for (const [name, peer] of Object.entries(remotePeers)) {
  new unifi.WireguardPeer(`wg_remote-${name}`, { networkId: wgRemote.id, name, ...peer });
}

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
