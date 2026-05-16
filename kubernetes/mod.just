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

[arg('resource', pattern='hr|ks|gitrepo|ocirepo|es')]
[doc('Sync a resource (optionally: just kube sync <resource> <ns> <name>)')]
[script]
sync resource ns="" name="":
    now=$(date +%s)
    if [ -n "{{ ns }}" ] && [ -n "{{ name }}" ]; then
        kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite {{ resource }} "{{ name }}" \
            "force-sync=$now" \
            "reconcile.fluxcd.io/requestedAt=$now" \
            "reconcile.fluxcd.io/forceAt=$now"
    else
        kubectl get {{ resource }} --no-headers -A | while read -r ns name _; do
            kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite {{ resource }} "$name" \
                "force-sync=$now" \
                "reconcile.fluxcd.io/requestedAt=$now" \
                "reconcile.fluxcd.io/forceAt=$now"
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
