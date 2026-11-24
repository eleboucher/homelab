import * as unifi from "@pulumi/unifi";
import { requireEnv } from "./env";

new unifi.Setting("site", {
  doh: {
    state: "custom",
    customServers: [
      // The stamp embeds the secret DoH path.
      { serverName: "blocky", sdnsStamp: requireEnv("BLOCKY_DOH_STAMP") },
      {
        serverName: "controld-unfiltered",
        sdnsStamp: "sdns://AgcAAAAAAAAACjc2Ljc2LjIuMTEAFGZyZWVkbnMuY29udHJvbGQuY29tAy9wMA",
      },
    ],
  },
  mdns: { enabledFor: "all", mode: "auto" },
  usg: { sendRedirects: false },
});
