import * as routeros from "@pulumi/routeros";
import { mgmtVlan } from "./interfaces";

new routeros.IpAddress("lan_gateway", {
  address: "192.168.1.2/24",
  network: "192.168.1.0",
  interface: mgmtVlan.name,
  comment: "Management",
});

new routeros.IpRoute("default-route", {
  dstAddress: "0.0.0.0/0",
  gateway: "192.168.1.1",
  comment: "Upstream to UCG",
});
