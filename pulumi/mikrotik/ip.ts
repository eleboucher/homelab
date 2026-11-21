import * as routeros from "@pulumi/routeros";
import { bridge } from "./interfaces";

new routeros.IpAddress("management", {
  address: "192.168.1.2/24",
  interface: bridge.name,
  network: "192.168.1.0",
});

new routeros.IpRoute("default-route", {
  dstAddress: "0.0.0.0/0",
  gateway: "192.168.1.1",
});

new routeros.IpDns("dns", {
  servers: ["192.168.1.1"],
  allowRemoteRequests: false,
});
