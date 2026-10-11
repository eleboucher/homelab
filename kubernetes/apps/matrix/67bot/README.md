# 67bot

Create a 1Password item named `67bot` with these fields:

- `ADMIN_PASSWORD`: maubot administrator password.
- `SERVER_SECRET`: random secret for management API tokens.
- `CRYPTO_PICKLE_KEY`: random secret for the Matrix crypto database; keep it stable.
- `FORGEJO_TOKEN`: token with `write:issue` access to `SableClient/sable-next`.

After Flux deploys the workload:

```sh
kubectl -n matrix port-forward svc/67bot 29316:29316
```

Open `http://localhost:29316/_matrix/maubot` and sign in as `admin`.
Register `@67bot:erwanleboucher.dev`, then create a fresh client session:

```sh
kubectl -n matrix exec -it deploy/67bot -- mbc login
kubectl -n matrix exec -it deploy/67bot -- mbc auth --homeserver erwanleboucher.dev --username 67bot --update-client
```

Create an instance named `67bot` using that client and plugin `moe.sable.67bot`.
The image bundles the defaults for `SableClient/sable-next` and `#sable:sable.moe`.
Invite the bot into the space and each room where it should respond.

The `/data` PVC stores accounts, devices, encryption keys, and plugin settings.
Kopiur backs it up. Secret changes restart the pod through Reloader.

[Source](https://git.sable.moe/SableClient/67bot) ·
[maubot setup](https://docs.mau.fi/maubot/usage/basic.html) ·
[Matrix authentication](https://docs.mau.fi/maubot/usage/cli/auth.html)
