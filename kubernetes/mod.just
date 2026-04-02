set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

[private]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --force-conflicts --field-manager=kustomize-controller -f /dev/stdin

[doc('Browse a PVC')]
browse-pvc namespace claim:
    kubectl browse-pvc -n {{ namespace }} -i mirror.gcr.io/alpine:latest {{ claim }}

[doc('Delete local Flux Kustomization')]
delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f /dev/stdin

[doc('Open a shell on a node')]
node-shell node:
    kubectl debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    for phase in Failed Pending Succeeded; do \
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true; \
    done


[doc('Sync ExternalSecrets (optionally: just kube sync-es <ns> <name>)')]
sync-es ns="" name="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{ ns }}" ] && [ -n "{{ name }}" ]; then
        kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite es "{{ name }}" \
            force-sync="$(date +%s)"
    else
        kubectl get es --no-headers -A | while read -r ns name _; do
            kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite es "$name" \
                force-sync="$(date +%s)"
        done
    fi

[doc('Sync GitRepositories')]
sync-git:
    kubectl get gitrepo --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite gitrepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync HelmReleases (optionally: just kube sync-hr <ns> <name>)')]
sync-hr ns="" name="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{ ns }}" ] && [ -n "{{ name }}" ]; then
        kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite hr "{{ name }}" \
            reconcile.fluxcd.io/requestedAt="$(date +%s)" reconcile.fluxcd.io/forceAt="$(date +%s)"
    else
        kubectl get hr --no-headers -A | while read -r ns name _; do
            kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite hr "$name" \
                reconcile.fluxcd.io/requestedAt="$(date +%s)" reconcile.fluxcd.io/forceAt="$(date +%s)"
        done
    fi

[doc('Sync Kustomizations (optionally: just kube sync-ks <ns> <name>)')]
sync-ks ns="" name="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{ ns }}" ] && [ -n "{{ name }}" ]; then
        kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite ks "{{ name }}" \
            reconcile.fluxcd.io/requestedAt="$(date +%s)"
    else
        kubectl get ks --no-headers -A | while read -r ns name _; do
            kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ks "$name" \
                reconcile.fluxcd.io/requestedAt="$(date +%s)"
        done
    fi

[doc('Sync OCIRepositories (optionally: just kube sync-oci <ns> <name>)')]
sync-oci ns="" name="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{ ns }}" ] && [ -n "{{ name }}" ]; then
        kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite ocirepo "{{ name }}" \
            reconcile.fluxcd.io/requestedAt="$(date +%s)"
    else
        kubectl get ocirepo --no-headers -A | while read -r ns name _; do
            kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ocirepo "$name" \
                reconcile.fluxcd.io/requestedAt="$(date +%s)"
        done
    fi

[doc('View a secret')]
view-secret namespace secret:
    kubectl view-secret -n {{ namespace }} {{ secret }}

[private]
render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" --path "{{ kubernetes_dir }}/flux/cluster" "{{ ks }}"
