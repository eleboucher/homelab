import * as routeros from "@pulumi/routeros";

const vlans = {
  mgmt: { name: "vlan10-mgmt", vlanId: 10, mtu: 1500, hwOffloaded: true },
};

type Ethernet = {
  comment: string;
  bridgePort?: boolean;
  l2mtu?: number;
  mtu?: number;
  untagged?: string;
};

const ethernetInterfaces: Record<string, Ethernet> = {
  ether1: { comment: "bond-kharkiv member", bridgePort: false, l2mtu: 9216, mtu: 9000 },
  ether2: { comment: "Access port", untagged: "vlan10-mgmt" },
  ether3: { comment: "bond-kharkiv member", bridgePort: false, l2mtu: 9216, mtu: 9000 },
  ether4: { comment: "Access port", untagged: "vlan10-mgmt" },
  ether5: { comment: "Access port", untagged: "vlan10-mgmt" },
  ether6: { comment: "Access port", untagged: "vlan10-mgmt" },
  ether7: { comment: "Access port", untagged: "vlan10-mgmt" },
  ether8: { comment: "Access port", untagged: "vlan10-mgmt" },
  "sfp-sfpplus1": { comment: "UCG uplink", untagged: "vlan10-mgmt" },
  "sfp-sfpplus2": { comment: "Access port", l2mtu: 9216, mtu: 9000, untagged: "vlan10-mgmt" },
};

const bondInterfaces = {
  "bond-kharkiv": {
    comment: "Kharkiv LACP (Management + Storage)",
    // Short label used in the bridge-port comment, matches what's on the device.
    shortLabel: "Kharkiv",
    slaves: ["ether1", "ether3"],
    mode: "802.3ad",
    transmitHashPolicy: "layer-3-and-4",
    mtu: 9000,
    untagged: "vlan10-mgmt",
  },
};

const vlanId = (name: string) => Object.values(vlans).find((v) => v.name === name)!.vlanId;

export const bridge1 = new routeros.InterfaceBridge("bridge1", {
  name: "bridge1",
  adminMac: "04:F4:1C:66:38:24",
  autoMac: false,
  vlanFiltering: true,
  igmpSnooping: true,
  pvid: 10,
});

const ethernet = Object.entries(ethernetInterfaces).map(
  ([name, port]) =>
    new routeros.InterfaceEthernet(`ethernet-${name}`, {
      factoryName: name,
      name,
      comment: port.comment,
      l2mtu: port.l2mtu,
      mtu: port.mtu,
    }),
);

const bonds = Object.entries(bondInterfaces).map(
  ([name, bond]) =>
    new routeros.InterfaceBonding(`bonds-${name}`, {
      name,
      comment: bond.comment,
      slaves: bond.slaves,
      mode: bond.mode,
      transmitHashPolicy: bond.transmitHashPolicy,
      mtu: bond.mtu,
      lacpRate: "1sec",
    }),
);

export const mgmtVlan = new routeros.InterfaceVlan("vlans-mgmt", {
  name: vlans.mgmt.name,
  interface: bridge1.name,
  vlanId: vlans.mgmt.vlanId,
  mtu: String(vlans.mgmt.mtu),
  hwOffloaded: vlans.mgmt.hwOffloaded,
});

const bridgePortMembers: Record<
  string,
  { comment: string; untagged?: string; frameTypes: string }
> = {
  ...Object.fromEntries(
    Object.entries(ethernetInterfaces)
      .filter(([, port]) => port.bridgePort ?? true)
      .map(([name, port]) => [
        name,
        {
          comment: port.comment,
          untagged: port.untagged,
          frameTypes: "admit-only-untagged-and-priority-tagged",
        },
      ]),
  ),
  ...Object.fromEntries(
    Object.entries(bondInterfaces).map(([name, bond]) => [
      name,
      {
        comment: `${bond.shortLabel} (VLAN ${vlanId(bond.untagged)} untagged)`,
        untagged: bond.untagged,
        frameTypes: "admit-all",
      },
    ]),
  ),
};

const ports = Object.entries(bridgePortMembers).map(
  ([name, member]) =>
    new routeros.InterfaceBridgePort(
      `ports-${name}`,
      {
        bridge: bridge1.name,
        interface: name,
        comment: member.comment,
        frameTypes: member.frameTypes,
        pvid: member.untagged ? vlanId(member.untagged) : 1,
      },
      { dependsOn: [...ethernet, ...bonds] },
    ),
);

for (const [key, vlan] of Object.entries(vlans)) {
  new routeros.InterfaceBridgeVlan(
    `bridge_vlans-${key}`,
    {
      bridge: bridge1.name,
      vlanIds: [String(vlan.vlanId)],
      taggeds: [bridge1.name],
      untaggeds: Object.entries(bridgePortMembers)
        .filter(([, member]) => member.untagged === vlan.name)
        .map(([name]) => name)
        .sort(),
    },
    { dependsOn: ports },
  );
}
