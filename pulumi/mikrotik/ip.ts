import * as routeros from "@pulumi/routeros";

new routeros.IpRoute("default-route", {
    dstAddress: "0.0.0.0/0",
    gateway: "192.168.1.254",
    comment: "Upstream to Freebox",
});

new routeros.IpUpnp("settings", { enabled: true });
