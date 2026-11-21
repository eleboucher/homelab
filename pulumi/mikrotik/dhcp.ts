import * as routeros from "@pulumi/routeros";
import { mgmtVlan } from "./interfaces";

new routeros.IpAddress("lan_gateway", {
    address: "192.168.1.2/24",
    network: "192.168.1.0",
    interface: mgmtVlan.name,
    comment: "LAN Gateway",
});

const pool = new routeros.IpPool("lan-pool", {
    name: "lan-pool",
    ranges: ["192.168.1.3-192.168.1.200"],
    comment: "LAN Pool",
});

const server = new routeros.IpDhcpServer("lan-dhcp-server", {
    name: "server1",
    interface: mgmtVlan.name,
    addressPool: pool.name,
    leaseTime: "1d",
    dynamicLeaseIdentifiers: "client-mac",
    useReconfigure: true,
    authoritative: "yes",
    comment: "LAN DHCP",
});

const domainSearch = new routeros.IpDhcpServerOption("domain_search_internal", {
    name: "domain-search-internal",
    code: 119,
    value: "0x08'internal'0x00",
});

new routeros.IpDhcpServerNetwork("lan-dhcp-network", {
    address: "192.168.1.0/24",
    gateway: "192.168.1.2",
    dnsServers: ["192.168.1.2"],
    domain: "internal",
    comment: "LAN Network",
    dhcpOptions: [domainSearch.name],
});

const staticLeases: Record<string, { mac: string; comment?: string; leaseTime?: string }> = {
    "192.168.1.41": { mac: "38:05:25:35:3B:9A", comment: "Kharkiv Management", leaseTime: "4w2d" },
    "192.168.1.153": { mac: "02:00:00:00:00:02", comment: "home assistant kubevirt" },
    "192.168.1.42": { mac: "C4:62:37:09:DF:FF", comment: "paris", leaseTime: "4w2d" },
    "192.168.1.140": { mac: "D0:CF:13:0D:B2:D0" },
    "192.168.1.135": { mac: "FC:9D:05:2B:EA:B1", comment: "cachyos desktop (Wake-on-LAN)" },
    "192.168.1.23": { mac: "C8:80:6D:69:92:5C", comment: "Mac mini (dev + macOS CI)" },
};

for (const [address, lease] of Object.entries(staticLeases)) {
    new routeros.IpDhcpServerLease(`static-${address}`, {
        address,
        macAddress: lease.mac,
        server: server.name,
        comment: lease.comment,
        leaseTime: lease.leaseTime,
    });
}
