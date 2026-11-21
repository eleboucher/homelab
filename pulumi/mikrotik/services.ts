import * as routeros from "@pulumi/routeros";

const disabled = ["telnet", "ftp", "api"];
const ports: Record<string, number> = { telnet: 23, ftp: 21, api: 8728 };

const off = disabled.map(
  (name) =>
    new routeros.IpService(`service-${name}`, { numbers: name, port: ports[name], disabled: true }),
);

// mikrotik-cert-sync installs the certificate on both.
for (const [name, port] of [
  ["www-ssl", 443],
  ["api-ssl", 8729],
] as const) {
  new routeros.IpService(
    `service-${name}`,
    { numbers: name, port, disabled: false },
    { dependsOn: off, ignoreChanges: ["certificate"] },
  );
}
