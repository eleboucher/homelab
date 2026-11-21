import * as unifi from "@pulumi/unifi";

new unifi.Setting("site", {
  doh: { state: "manual", serverNames: ["cloudflare"] },
  mdns: { enabledFor: "all", mode: "auto" },
  usg: { sendRedirects: false },
});
