import * as unifi from "@pulumi/unifi";
import { requireEnv } from "./env";
import { lan } from "./network";

const apGroup = unifi.getApGroupOutput({ name: "All APs" });
const clientGroup = unifi.getClientQosRateOutput({ name: "Default" });

new unifi.Wlan("home", {
  name: requireEnv("WIFI_SSID"),
  security: "wpapsk",
  wpa3: { support: true, transition: true },
  pmfMode: "optional",
  wlanBands: ["2g", "5g", "6g"],
  roamingAssistant6e: { enabled: true, rssi: -75 },
  passphraseWo: requireEnv("WIFI_PASSPHRASE"),
  passphraseWoVersion: 1,
  networkId: lan.id,
  userGroupId: clientGroup.id,
  apGroup: { ids: [apGroup.id] },
});
