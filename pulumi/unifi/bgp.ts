import * as fs from "fs";
import * as path from "path";
import * as unifi from "@pulumi/unifi";

// Peers with Cilium (AS 64514) on both nodes and imports only the LoadBalancer pools.
new unifi.Bgp("cilium", {
  description: "Cilium",
  enabled: true,
  uploadFileName: "bgp.conf",
  config: fs.readFileSync(path.join(__dirname, "bgp.conf"), "utf8"),
});
