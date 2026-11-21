import * as unifi from "@pulumi/unifi";

const staticDnsRecords: Record<string, string> = {
  "router.erwanleboucher.dev": "192.168.1.2",
  "unifi.erwanleboucher.dev": "192.168.1.1",
  "kharkiv.k8s.internal": "192.168.1.41",
  "paris.k8s.internal": "192.168.1.42",
  "k8s.internal": "192.168.1.42",
  "normandie.internal": "192.168.1.40",
  "macmini.internal": "192.168.1.23",
};

for (const [name, value] of Object.entries(staticDnsRecords)) {
  new unifi.DnsRecord(`static-${name}`, { name, recordType: "A", value });
}

const staticAaaaRecords: Record<string, string> = {
  "unifi.erwanleboucher.dev": "2a01:e0a:e4b:aa31::1",
  "kharkiv.k8s.internal": "2a01:e0a:e4b:aa31::43",
  "paris.k8s.internal": "2a01:e0a:e4b:aa31::42",
  "k8s.internal": "2a01:e0a:e4b:aa31::42",
};

for (const [name, value] of Object.entries(staticAaaaRecords)) {
  new unifi.DnsRecord(`static-aaaa-${name}`, { name, recordType: "AAAA", value });
}
