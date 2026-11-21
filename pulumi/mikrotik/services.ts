import * as routeros from "@pulumi/routeros";

const disabled: Record<string, number> = { telnet: 23, ftp: 21, api: 8728 };

const off = Object.entries(disabled).map(
  ([name, port]) =>
    new routeros.IpService(`service-${name}`, { numbers: name, port, disabled: true }),
);

const certificate = new routeros.SystemCertificate("tls", {
  name: "switch",
  commonName: "router.erwanleboucher.dev",
  subjectAltName: "DNS:router.erwanleboucher.dev,IP:192.168.1.2",
  daysValid: 3650,
  keySize: "2048",
  keyUsages: ["digital-signature", "key-encipherment", "key-cert-sign", "tls-server"],
  signs: [{}],
});

for (const [name, port] of [
  ["www-ssl", 443],
  ["api-ssl", 8729],
] as const) {
  new routeros.IpService(
    `service-${name}`,
    { numbers: name, port, disabled: false, certificate: certificate.name },
    { dependsOn: off },
  );
}
