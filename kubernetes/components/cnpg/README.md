# CNPG Component

Minimal CloudNativePG cluster template for spawning lightweight PostgreSQL instances.

## Features

- Single instance (lightweight)
- Longhorn storage (10Gi default)
- Resource limits: 256Mi-1Gi RAM, 100m-1000m CPU
- Pod monitoring enabled
- Variable substitution for app name
- All credentials managed via onepassword/ExternalSecrets (superuser + app user)
- Automatic database and owner creation via initdb
- pgvector extensions (vchord + vector) for AI/ML workloads

## Prerequisites

Ensure the following onepassword entry exists with these fields:
- **onepassword item**: `cloudnative-pg`
  - `POSTGRES_SUPER_USER`: PostgreSQL superuser username
  - `POSTGRES_SUPER_PASS`: PostgreSQL superuser password
  - `POSTGRES_APP_USER`: Application user username (typically same as `${APP}`)
  - `POSTGRES_APP_PASS`: Application user password

## Usage

### In your app's kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../components/cnpg
```

### In your Flux Kustomization (ks.yaml)

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 1h
  path: ./kubernetes/apps/myapp/app
  dependsOn:
    - name: cloudnative-pg
    - name: external-secrets-store
  postBuild:
    substitute:
      APP: myapp
  targetNamespace: myapp
```

## What Gets Created

### Resources
- **ExternalSecret**: `${APP}-cnpg-secret` - Syncs superuser credentials from onepassword
- **Cluster**: `postgres-${APP}` - PostgreSQL cluster
- **Database**: `${APP}` - Application database
- **User**: `${APP}` - Database owner
- **Service**: `postgres-${APP}-rw` - Read-write service (port 5432)
- **Service**: `postgres-${APP}-ro` - Read-only service (port 5432)

### Secrets (Created from onepassword)

**1. `${APP}-cnpg-secret`** (superuser credentials)
- `username`: PostgreSQL superuser username
- `password`: PostgreSQL superuser password


## Connection

**For applications** (recommended - least privilege):

Use the app user credentials from `postgres-${APP}-app`:

```yaml
env:
  - name: POSTGRES_HOST
    value: postgres-${APP}-rw.${NAMESPACE}.svc.cluster.local
  - name: POSTGRES_PORT
    value: "5432"
  - name: POSTGRES_DB
    value: ${APP}
  - name: POSTGRES_USER
    valueFrom:
      secretKeyRef:
        name: postgres-${APP}-app
        key: username
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-${APP}-app
        key: password
```

**For administration** (use sparingly):

Use superuser credentials from `${APP}-cnpg-secret` for administrative tasks only.

## Customization

Override defaults in your app's kustomization:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../components/cnpg

patches:
  - target:
      kind: Cluster
      name: postgres-.*
    patch: |-
      - op: replace
        path: /spec/storage/size
        value: 20Gi
      - op: replace
        path: /spec/instances
        value: 3
```
