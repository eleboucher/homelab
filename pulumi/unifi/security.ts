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
  mdns: { enabledFor: "all", mode: "auto" },
  usg: { sendRedirects: false },
});
