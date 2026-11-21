import * as unifi from "@pulumi/unifi";

new unifi.Setting("site", {
  doh: { state: "manual", serverNames: ["cloudflare"] },
  mdns: { enabledFor: "some", mode: "auto" },
});
