import * as routeros from "@pulumi/routeros";

const ports = [
  "ether1",
  "ether2",
  "ether3",
  "ether4",
  "ether5",
  "ether6",
  "ether7",
  "ether8",
  "sfp-sfpplus1",
  "sfp-sfpplus2",
];

const ethernet = ports.map(
  (name) =>
    new routeros.InterfaceEthernet(`ethernet-${name}`, { factoryName: name, name, l2mtu: 9216 }),
);

export const bridge = new routeros.InterfaceBridge("bridge", {
  name: "bridge",
  adminMac: "04:F4:1C:66:38:20",
  autoMac: false,
  protocolMode: "rstp",
});

const bond = new routeros.InterfaceBonding(
  "bond-kharkiv",
  {
    name: "bond-kharkiv",
    comment: "Kharkiv LACP",
    slaves: ["ether1", "ether3"],
    mode: "802.3ad",
    transmitHashPolicy: "layer-3-and-4",
    lacpRate: "1sec",
    mtu: 9000,
  },
  { dependsOn: ethernet },
);

const bondMembers = ["ether1", "ether3"];

for (const name of [...ports.filter((p) => !bondMembers.includes(p)), "bond-kharkiv"]) {
  new routeros.InterfaceBridgePort(
    `port-${name}`,
    { bridge: bridge.name, interface: name },
    { dependsOn: [...ethernet, bond] },
  );
}
