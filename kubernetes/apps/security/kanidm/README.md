# Kanidm

## Initial Setup

### 1. Recover admin accounts

After first deployment, recover both built-in accounts:

```bash
kubectl exec -n security -it statefulset/kanidm -- kanidmd recover-account admin 
kubectl exec -n security -it statefulset/kanidm -- kanidmd recover-account idm_admin
```

Log in with each recovery token and set a real password via the web UI at `https://idm.erwanleboucher.dev/ui/reset`.

### 2. Create the provision service account

```bash
kanidm service-account create kanidm-provision "Kanidm Provision" idm_admins -D idm_admin
kanidm group add-members idm_admins kanidm-provision -D idm_admin
kanidm service-account api-token generate --readwrite kanidm-provision provision-token -D idm_admin
```

Store the token in 1Password as item `kanidm-provision` → field `token`.

### 3. Create groups

```bash
kanidm group create users --url https://idm.erwanleboucher.dev -D idm_admin
kanidm group create admins --url https://idm.erwanleboucher.dev -D idm_admin
```

### 4. Create your personal account

```bash
kanidm person create <username> "<Display Name>" -D idm_admin
kanidm person update <username> --mail "<email>" -D idm_admin
kanidm group add-members users <username> -D idm_admin
kanidm group add-members admins <username> -D idm_admin
kanidm group add-members idm_admins <username> -D idm_admin
kanidm person credential create-reset-token <username> -D idm_admin
```

Use the reset token to set a password or enroll a passkey at `https://idm.erwanleboucher.dev`.
