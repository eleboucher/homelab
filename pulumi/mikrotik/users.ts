import * as pulumi from "@pulumi/pulumi";
import * as routeros from "@pulumi/routeros";

const userGroups: Record<string, string[]> = {
    mktxp_group: [
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
    homepage: [
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
    "wg-portal": [
        "read",
        "write",
        "sensitive",
        "api",
        "rest-api",
        "!local",
        "!telnet",
        "!ssh",
        "!ftp",
        "!reboot",
        "!policy",
        "!test",
        "!winbox",
        "!password",
        "!web",
        "!sniff",
        "!romon",
    ],
    home_assistant: [
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
};

// passwordEnv is only read when a user is first created; later changes are ignored.
const users: Record<string, { group: string; address?: string; passwordEnv?: string }> = {
    admin: { group: "full" },
    mktxp_user: {
        group: "mktxp_group",
        address: "192.168.1.0/24,10.42.0.0/16",
        passwordEnv: "USER_PASSWORD_MKTXP_USER",
    },
    "wg-portal": { group: "wg-portal", address: "192.168.1.0/24,10.42.0.0/16", passwordEnv: "USER_PASSWORD_WG_PORTAL" },
    homepage: { group: "homepage", passwordEnv: "USER_PASSWORD_HOMEPAGE" },
    "home-assistant": {
        group: "home_assistant",
        address: "192.168.1.0/24,10.42.0.0/16",
        passwordEnv: "USER_PASSWORD_HOME_ASSISTANT",
    },
};

const groups = Object.entries(userGroups).map(
    ([name, policies]) => new routeros.SystemUserGroup(`group-${name}`, { name, policies }),
);

for (const [name, user] of Object.entries(users)) {
    const password = user.passwordEnv ? process.env[user.passwordEnv] : undefined;
    new routeros.SystemUser(
        `user-${name}`,
        {
            name,
            group: user.group,
            address: user.address,
            password: password ? pulumi.secret(password) : undefined,
        },
        { dependsOn: groups, ignoreChanges: ["password"] },
    );
}
