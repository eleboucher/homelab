set lazy
set positional-arguments
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

[private]
[script]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
[script]
apply-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --force-conflicts --field-manager=kustomize-controller -f -

[doc('Browse a PVC')]
[script]
browse-pvc namespace claim:
    kubectl browse-pvc -n {{ namespace }} -i mirror.gcr.io/alpine:latest {{ claim }}

[doc('Delete local Flux Kustomization')]
[script]
delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f -

[doc('Restart Home Assistant VM (fixes Bluetooth USB passthrough)')]
[script]
restart-ha:
    kubectl virt restart home-assistant -n home-assistant

[doc('Open a shell on a node')]
[script]
node-shell node:
    kubectl debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Prune pods in Failed, Pending, or Succeeded state')]
[script]
prune-pods:
    for phase in Failed Pending Succeeded; do
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true
    done

[doc('Sync ExternalSecrets (optionally: just kube sync-es <ns> <name>)')]
[script]
sync-es ns="" name="":
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
[script]
sync-git:
    kubectl get gitrepo --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite gitrepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"
    done

[doc('Sync HelmReleases (optionally: just kube sync-hr <ns> <name>)')]
[script]
sync-hr ns="" name="":
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
[script]
sync-ks ns="" name="":
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
[script]
sync-oci ns="" name="":
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
[script]
view-secret namespace secret:
    kubectl view-secret -n {{ namespace }} {{ secret }}

[private]
[script]
render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" --sources "flux-system=." --path "{{ kubernetes_dir }}/flux/cluster" "{{ ks }}"
