import * as unifi from "@pulumi/unifi";

// ExternalDNS owns every *.erwanleboucher.dev record; only static entries here.
const staticDnsRecords: Record<string, string> = {
  "router.erwanleboucher.dev": "192.168.1.2",
  "kharkiv.k8s.internal": "192.168.1.41",
  "paris.k8s.internal": "192.168.1.42",
  "k8s.internal": "192.168.1.42",
  "normandie.internal": "192.168.1.40",
  "macmini.internal": "192.168.1.23",
};

for (const [name, value] of Object.entries(staticDnsRecords)) {
  new unifi.DnsRecord(`static-${name}`, { name, recordType: "A", value });
}
