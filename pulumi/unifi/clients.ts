import * as unifi from "@pulumi/unifi";

const fixedClients: Record<string, { mac: string; name?: string }> = {
    "192.168.1.41": { mac: "38:05:25:35:3B:9A", name: "Kharkiv Management" },
    "192.168.1.153": { mac: "02:00:00:00:00:02", name: "home assistant kubevirt" },
    "192.168.1.42": { mac: "C4:62:37:09:DF:FF", name: "paris" },
    "192.168.1.140": { mac: "D0:CF:13:0D:B2:D0" },
    "192.168.1.135": { mac: "FC:9D:05:2B:EA:B1", name: "cachyos desktop (Wake-on-LAN)" },
    "192.168.1.23": { mac: "C8:80:6D:69:92:5C", name: "Mac mini (dev + macOS CI)" },
};

for (const [fixedIp, client] of Object.entries(fixedClients)) {
    new unifi.Client(`fixed-${fixedIp}`, { mac: client.mac.toLowerCase(), name: client.name, fixedIp });
}
