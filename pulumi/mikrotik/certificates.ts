import * as routeros from "@pulumi/routeros";

new routeros.SystemCertificate("mikrotik_api", {
    name: "mikrotik-api",
    commonName: "192.168.1.2",
    daysValid: 3650,
    keySize: "2048",
    keyUsages: [
        "digital-signature",
        "key-encipherment",
        "data-encipherment",
        "key-cert-sign",
        "crl-sign",
        "tls-server",
        "tls-client",
    ],
    trusted: true,
});
