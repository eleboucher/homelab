import * as unifi from "@pulumi/unifi";
import { lan } from "./network";

new unifi.Setting("site", {
  doh: { state: "manual", serverNames: ["cloudflare"] },
  // Reflects mDNS between the networks that have it enabled (LAN and IoT).
  mdns: { enabledFor: "some", mode: "auto" },
});

new unifi.ContentFilter("lan", {
  name: "LAN",
  networkIds: [lan.id],
  categories: ["ADVERTISEMENT", "MALWARE", "PHISHING"],
});
