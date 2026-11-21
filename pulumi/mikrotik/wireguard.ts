import * as routeros from "@pulumi/routeros";

export const wgMb = new routeros.InterfaceWireguard(
  "wg_mb",
  { name: "wg-mb", listenPort: 51820, mtu: "1420" },
  { ignoreChanges: ["privateKey"] },
);

new routeros.InterfaceWireguardPeer("wg_mb_mortebrume", {
  name: "peer1",
  interface: wgMb.name,
  publicKey: "w/cHbGqlFMFdcNxaqT5BvRV3nMpm9J3gx5T/WIMhcxY=",
  endpointAddress: "2a01:4f8:242:4691:ffff::1",
  endpointPort: "51771",
  allowedAddresses: ["10.222.0.0/16", "fd4d:ac20:c274::/48", "fe80::1/128"],
});

const wgRemote = new routeros.InterfaceWireguard(
  "wg_remote",
  { name: "wg-remote", listenPort: 51821, mtu: "1420" },
  { ignoreChanges: ["privateKey"] },
);

new routeros.IpAddress("wg_remote-address", {
  address: "10.10.0.1/24",
  interface: wgRemote.name,
  network: "10.10.0.0",
});
