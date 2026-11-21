import * as fs from "fs";
import * as path from "path";
import * as unifi from "@pulumi/unifi";

new unifi.Bgp("cilium", {
  description: "Cilium",
  enabled: true,
  uploadFileName: "bgp.conf",
  config: fs.readFileSync(path.join(__dirname, "bgp.conf"), "utf8"),
});
