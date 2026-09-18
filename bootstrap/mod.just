set no-exit-message
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

topf_config := justfile_dir() / "talos" / "topf.yaml"

[private]
default:
    just -l bootstrap

[confirm('Bootstrap cluster? [y|N]')]
[doc('Bootstrap a Talos & Kubernetes cluster end-to-end')]
cluster: apply credentials base apps

[private]
[script]
apply:
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! topf --topfconfig "{{ topf_config }}" apply --auto-bootstrap; then
        just log fatal "Failed to apply Talos configuration / bootstrap" "stage" "$(basename "$0")"
    fi

[private]
[script]
credentials:
    just log info "Running stage..." "stage" "$(basename "$0")"
    topf --topfconfig "{{ topf_config }}" talosconfig > "{{ justfile_dir() }}/talosconfig"
    topf --topfconfig "{{ topf_config }}" kubeconfig --validity 720h > "{{ justfile_dir() }}/kubeconfig"
    # The cluster endpoint (k8s.internal) is only reachable once Cilium announces
    # its LoadBalancer VIP, so during bootstrap target the control-plane node directly.
    cp="$(yq -e '.nodes[] | select(.role == "control-plane") | (.ip // .host)' "{{ topf_config }}" | head -1)"
    cluster_name="$(kubectl --kubeconfig "{{ justfile_dir() }}/kubeconfig" config view -o jsonpath='{.clusters[0].name}')"
    kubectl --kubeconfig "{{ justfile_dir() }}/kubeconfig" config set-cluster "$cluster_name" --server "https://${cp}:6443"

[private]
[script]
base: ready
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! kustomize build {{ source_directory() }}/kustomize/apps | just template - | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply base manifests" "stage" "$(basename "$0")"
    fi
    if ! helmfile -f "{{ source_directory() }}/helmfile/crds.yaml" template -q | yq ea -e 'select(.kind == "CustomResourceDefinition")' | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply crds" "stage" "$(basename "$0")"
    fi

[private]
[script]
apps:
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! helmfile -f "{{ source_directory() }}/helmfile/apps.yaml" sync --hide-notes; then
        just log fatal "Failed to sync helmfile" "stage" "$(basename "$0")"
    fi

# Wait until nodes register as Ready=False. They only become Ready=True once the CNI is healthy.
[private]
[script]
ready:
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..." "stage" "$(basename "$0")"
            sleep 5
        done
    fi
