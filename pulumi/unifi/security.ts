import * as unifi from "@pulumi/unifi";
import { requireEnv } from "./env";

new unifi.Setting("site", {
  doh: {
    state: "custom",
    serverNames: ["cloudflare"],
    customServers: [
      // The stamp embeds the secret DoH path.
      { serverName: "blocky", sdnsStamp: requireEnv("BLOCKY_DOH_STAMP") },
    ],
  },
  mdns: {
    enabledFor: "all",
    mode: "custom",
    predefinedServices: ["google_chromecast", "apple_airPlay", "homeKit"],
    customServices: [{ name: "ESPHome", address: "_esphomelib._tcp.local" }],
  },
  usg: { sendRedirects: false },
});
