import * as pulumi from "@pulumi/pulumi";
import * as unifi from "@pulumi/unifi";

// Keys carried over from the MikroTik so existing peers keep working.
const requireEnv = (name: string) => {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return pulumi.secret(value);
};

// Remote access, replacing wg-remote on the MikroTik.
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

// vx0 tunnel to mortebrume, replacing wg-mb on the MikroTik. BGP runs over the
// link-local addresses (fe80::2 here, fe80::1 there); see bgp.conf. UniFi wants
// an IPv4 tunnel address, so it gets the last address of our vx0 prefix, which
// Cilium's LB IPAM never hands out.
export const vx0 = new unifi.VpnClient("vx0", {
  name: "vx0",
  subnet: "10.222.5.15/32",
  ipv6Subnet: "fe80::2/64",
  defaultRoute: false,
  pullDns: false,
  wireguard: {
    privateKeyWo: requireEnv("VX0_PRIVATE_KEY"),
    privateKeyWoVersion: 1,
    interface: "wan",
    dnsServers: ["192.168.1.1"],
    peer: {
      ip: "2a01:4f8:242:4691:ffff::1",
      port: 51771,
      publicKey: "w/cHbGqlFMFdcNxaqT5BvRV3nMpm9J3gx5T/WIMhcxY=",
    },
  },
});

// Aggregate announced to vx0; the /32 LoadBalancer routes from Cilium are more specific.
new unifi.StaticRoute("vx0_aggregate", {
  name: "vx0 aggregate",
  type: "blackhole",
  network: "10.222.5.0/28",
  distance: 1,
});
