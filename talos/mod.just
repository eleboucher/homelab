set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# Requires `op` authenticated (vals resolves ref+op:// in secrets.yaml).
topf_config := source_directory() / "topf.yaml"

[private]
default:
    just -l talos

[doc('List all nodes and their live state')]
nodes:
    topf --topfconfig "{{ topf_config }}" nodes

[doc('Render machine configs for all nodes to a directory (default: /tmp/topf-render)')]
render out="/tmp/topf-render":
    topf --topfconfig "{{ topf_config }}" render -o "{{ out }}"
    just log info "Rendered machine configs" "out" "{{ out }}"

[doc('Show the pending config diff against the live cluster (dry-run, applies nothing)')]
diff *args:
    topf --topfconfig "{{ topf_config }}" apply --dry-run {{ args }}

[confirm('Apply Talos config to ' + node + ' [y|N] ?')]
[doc('Apply Talos config to a node (extra flags pass through, e.g. --mode=no-reboot)')]
apply-node node *args:
    topf --topfconfig "{{ topf_config }}" apply --nodes-filter "{{ node }}" {{ args }}

[confirm('Reboot node ' + node + ' [y|N] ?')]
[doc('Reboot a node')]
reboot-node node:
    talosctl -n {{ node }} reboot -m powercycle

[doc('Render Talos config for a node and print it')]
[script]
render-config node:
    out="$(mktemp -d)"
    topf --topfconfig "{{ topf_config }}" render --nodes-filter "{{ node }}" -o "$out" >/dev/null
    cat "$out/{{ node }}.yaml"
    rm -rf "$out"

[doc('Fetch kubeconfig and talosconfig, then restart controllers (use after a Talos apply)')]
[script]
kubeconfig:
    topf --topfconfig "{{ topf_config }}" talosconfig > "{{ justfile_dir() }}/talosconfig"
    topf --topfconfig "{{ topf_config }}" kubeconfig --validity 720h > "{{ justfile_dir() }}/kubeconfig"
    namespaces=(kube-system observability cert-manager security flux-system cnpg-system volsync-system)
    for ns in "${namespaces[@]}"; do
        if kubectl get ns "$ns" >/dev/null 2>&1; then
            kubectl rollout restart -n "$ns" deploy ds
        fi
    done

[confirm('Reset node ' + node + ' [y|N] ?')]
[doc('Reset a node')]
reset-node node *args:
    talosctl -n "{{ node }}" reset --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --system-labels-to-wipe u-local-hostpath --graceful=false {{ args }}

[confirm('Shutdown node ' + node + ' [y|N] ?')]
[doc('Shutdown a node')]
shutdown-node node *args:
    talosctl -n "{{ node }}" shutdown --force {{ args }}

[confirm('Upgrade Kubernetes to ' + version + ' [y|N] ?')]
[doc('Upgrade Kubernetes on the cluster (topf does not manage k8s; bump kubernetesVersion in topf.yaml afterwards)')]
upgrade-k8s version:
    talosctl -n "$(talosctl config info -o yaml | yq -e '.endpoints[0]')" upgrade-k8s --to {{ version }}

[confirm('Upgrade node ' + node + ' [y|N] ?')]
[doc('Upgrade Talos on a node to the version in topf.yaml')]
upgrade-node node *args:
    topf --topfconfig "{{ topf_config }}" upgrade --nodes-filter "{{ node }}" --reboot-mode powercycle {{ args }}

[doc('Print the resolved schematic ID')]
schematic-id:
    topf --topfconfig "{{ topf_config }}" schematic-ids

[doc('Download Talos machine image')]
[script]
download-image version:
    schematic="$(topf --topfconfig "{{ topf_config }}" schematic-ids | head -1)"
    gum spin --title "Downloading Talos {{ version }} ..." -- \
    curl -sfL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors \
        -o "{{ source_directory() }}/talos-{{ version }}-${schematic:0:8}.iso" \
        "https://factory.talos.dev/image/${schematic}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "${schematic}"

[confirm('Create ZFS pool data-pool on ' + node + ' using ' + disk + ' — this WIPES the disk [y|N] ?')]
[doc('Create the OpenEBS ZFS pool on a node (wipes the target disk)')]
[script]
zpool-create node disk:
    # Talos has no shell on the host; exec the extension's zpool binary directly via nsenter
    overrides="$(jq -n --arg node "{{ node }}" --arg disk "{{ disk }}" \
        '{spec:{nodeName:$node,hostNetwork:true,hostPID:true,containers:[{name:"zpool",image:"alpine:3.21",securityContext:{privileged:true},command:["nsenter","-t","1","-m","-u","-i","-n","--","/usr/local/sbin/zpool","create","-f","-m","none","-o","ashift=12","-O","compression=zstd","-O","atime=off","-O","xattr=sa","data-pool",$disk]}]}}')"
    kubectl run "zpool-create-{{ node }}" --restart=Never --image=alpine:3.21 --overrides="$overrides"
    kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/zpool-create-{{ node }}" --timeout=120s
    kubectl logs "zpool-create-{{ node }}"
    kubectl delete pod "zpool-create-{{ node }}"
    just talos zpool-status "{{ node }}"

[doc('Show ZFS pool status on a node')]
[script]
zpool-status node:
    overrides="$(jq -n --arg node "{{ node }}" \
        '{spec:{nodeName:$node,hostNetwork:true,hostPID:true,containers:[{name:"zpool",image:"alpine:3.21",securityContext:{privileged:true},command:["nsenter","-t","1","-m","-u","-i","-n","--","/usr/local/sbin/zpool","status"]}]}}')"
    kubectl run "zpool-status-{{ node }}" --restart=Never --image=alpine:3.21 --overrides="$overrides"
    kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/zpool-status-{{ node }}" --timeout=120s
    kubectl logs "zpool-status-{{ node }}"
    kubectl delete pod "zpool-status-{{ node }}"

[confirm('Destroy ZFS pool data-pool on ' + node + ' — THIS IRREVERSIBLY DESTROYS ALL POOL DATA [y|N] ?')]
[doc('Destroy the OpenEBS ZFS pool on a node (irreversible)')]
[script]
zpool-destroy node:
    overrides="$(jq -n --arg node "{{ node }}" \
        '{spec:{nodeName:$node,hostNetwork:true,hostPID:true,containers:[{name:"zpool",image:"alpine:3.21",securityContext:{privileged:true},command:["nsenter","-t","1","-m","-u","-i","-n","--","/usr/local/sbin/zpool","destroy","-f","data-pool"]}]}}')"
    kubectl run "zpool-destroy-{{ node }}" --restart=Never --image=alpine:3.21 --overrides="$overrides"
    kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/zpool-destroy-{{ node }}" --timeout=120s
    kubectl logs "zpool-destroy-{{ node }}"
    kubectl delete pod "zpool-destroy-{{ node }}"
