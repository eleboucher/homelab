import * as unifi from "@pulumi/unifi";
import { requireEnv } from "./env";
import { lan } from "./network";

// The groups every UniFi site ships with.
const apGroup = unifi.getApGroupOutput({ name: "All APs" });
const clientGroup = unifi.getClientQosRateOutput({ name: "Default" });

// Same SSID and passphrase as the Freebox, so clients move over without being touched.
new unifi.Wlan("home", {
  name: requireEnv("WIFI_SSID"),
  security: "wpapsk",
  // WPA2/WPA3 transition mode, as on the Freebox.
  wpa3: { support: true, transition: true },
  pmfMode: "optional",
  // The U7 Pro is tri-band; 6 GHz clients join with WPA3.
  wlanBands: ["2g", "5g", "6g"],
  passphraseWo: requireEnv("WIFI_PASSPHRASE"),
  passphraseWoVersion: 1,
  networkId: lan.id,
  userGroupId: clientGroup.id,
  apGroup: { ids: [apGroup.id] },
});
