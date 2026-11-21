import * as unifi from "@pulumi/unifi";
import { lan } from "./network";

new unifi.Setting("site", {
  doh: { state: "manual", serverNames: ["cloudflare"] },
});

new unifi.ContentFilter("lan", {
  name: "LAN",
  networkIds: [lan.id],
  categories: ["ADVERTISEMENT", "MALWARE", "PHISHING"],
});
