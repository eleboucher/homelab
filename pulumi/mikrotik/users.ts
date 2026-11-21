import * as pulumi from "@pulumi/pulumi";
import * as routeros from "@pulumi/routeros";

const requireEnv = (name: string) => {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return pulumi.secret(value);
};

const lanAndPods = "192.168.1.0/24,10.42.0.0/16";

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

const homeAssistantGroup = new routeros.SystemUserGroup("group-home-assistant", {
  name: "home_assistant",
  policies: [
    "read",
    "api",
    "test",
    "!local",
    "!telnet",
    "!ssh",
    "!ftp",
    "!reboot",
    "!write",
    "!policy",
    "!winbox",
    "!password",
    "!web",
    "!sniff",
    "!sensitive",
    "!romon",
    "!rest-api",
  ],
});

new routeros.SystemUser(
  "user-home-assistant",
  {
    name: "home-assistant",
    group: homeAssistantGroup.name,
    address: lanAndPods,
    password: requireEnv("USER_PASSWORD_HOME_ASSISTANT"),
  },
  { ignoreChanges: ["password"] },
);
