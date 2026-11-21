import * as routeros from "@pulumi/routeros";

new routeros.SystemIdentity("identity", { name: "MikroTik" });

new routeros.SystemClock("clock", {
  timeZoneName: "Europe/Paris",
  timeZoneAutodetect: false,
});

new routeros.SystemNtpClient("ntp-client", {
  enabled: true,
  mode: "unicast",
  servers: ["time.cloudflare.com"],
});
