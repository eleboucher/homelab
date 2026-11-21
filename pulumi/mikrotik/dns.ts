import * as routeros from "@pulumi/routeros";

new routeros.IpDns("server", {
    allowRemoteRequests: true,
    servers: ["192.168.1.1"],
    cacheSize: 20480,
    cacheMaxTtl: "1d",
    maxConcurrentQueries: 500,
    maxConcurrentTcpSessions: 100,
    queryServerTimeout: "8s",
});

// ExternalDNS owns every *.erwanleboucher.dev record; only router-local entries here.
const staticDnsRecords: Record<string, string> = {
    "router.erwanleboucher.dev": "192.168.1.2",
    "kharkiv.k8s.internal": "192.168.1.41",
    "paris.k8s.internal": "192.168.1.42",
    "normandie.internal": "192.168.1.40",
    "macmini.internal": "192.168.1.23",
};

for (const [name, address] of Object.entries(staticDnsRecords)) {
    new routeros.IpDnsRecord(`static-${name}`, { name, type: "A", address });
}

// A record for the Kubernetes API — paris is the sole control plane.
for (const address of ["192.168.1.42"]) {
    new routeros.IpDnsRecord(`k8s_api-${address}`, { name: "k8s.internal", type: "A", address });
}
