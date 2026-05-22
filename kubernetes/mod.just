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
    kubectl run -n {{ namespace }} browse-pvc-{{ claim }} -it --rm --restart=Never \
        --image=mirror.gcr.io/alpine:latest \
        --overrides='{"spec":{"containers":[{"name":"browse-pvc-{{ claim }}","image":"mirror.gcr.io/alpine:latest","stdin":true,"tty":true,"command":["/bin/sh"],"workingDir":"/mnt","volumeMounts":[{"mountPath":"/mnt","name":"data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"{{ claim }}"}}]}}'

[doc('Debug a node')]
[script]
debug-node node:
    trap 'kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug --field-selector spec.nodeName={{ node }} --ignore-not-found --wait=false' EXIT
    kubectl debug node/{{ node }} -n default -it --image=mirror.gcr.io/alpine:latest --profile=sysadmin

[doc('Delete local Flux Kustomization')]
[script]
delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f -

[doc('Restart Home Assistant VM (fixes Bluetooth USB passthrough)')]
[script]
restart-ha:
    kubectl virt restart home-assistant -n home-assistant

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
