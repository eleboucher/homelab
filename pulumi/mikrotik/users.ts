import { randomBytes } from "node:crypto";
import * as pulumi from "@pulumi/pulumi";
import * as routeros from "@pulumi/routeros";

const requireEnv = (name: string) => {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return pulumi.secret(value);
};

const lanAndPods = "192.168.1.0/24,10.42.0.0/16";

// Read-only API access for the exporter and the homepage widget.
const exporterGroup = new routeros.SystemUserGroup("group-mktxp", {
  name: "mktxp_group",
  policies: [
    "read",
    "api",
    "rest-api",
    "!local",
    "!telnet",
    "!ssh",
    "!ftp",
    "!reboot",
    "!write",
    "!policy",
    "!test",
    "!winbox",
    "!password",
    "!web",
    "!sniff",
    "!sensitive",
    "!romon",
  ],
});

new routeros.SystemUser(
  "user-mktxp",
  {
    name: "mktxp_user",
    group: exporterGroup.name,
    address: lanAndPods,
    password: requireEnv("USER_PASSWORD_MKTXP_USER"),
  },
  { ignoreChanges: ["password"] },
);

// Used by the mikrotik-cert-sync job to install the TLS certificate over SSH.
const certSyncGroup = new routeros.SystemUserGroup("group-cert-sync", {
  name: "cert-sync",
  policies: [
    "ssh",
    "ftp",
    "read",
    "write",
    "sensitive",
    "!local",
    "!telnet",
    "!reboot",
    "!policy",
    "!test",
    "!winbox",
    "!password",
    "!web",
    "!sniff",
    "!api",
    "!rest-api",
    "!romon",
  ],
});

const certSync = new routeros.SystemUser(
  "user-cert-sync",
  {
    name: "cert-sync",
    group: certSyncGroup.name,
    address: lanAndPods,
    // RouterOS requires a password; this user only logs in with its SSH key.
    password: pulumi.secret(randomBytes(32).toString("base64url")),
  },
  { ignoreChanges: ["password"] },
);

new routeros.SystemUserSshkeys("cert-sync-key", {
  user: certSync.name,
  key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINIaRU2OXr7Ots4zKPgNuAN/KiGj4Q5cGBELX/VVXqZf",
});
