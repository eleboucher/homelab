set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l talos

[confirm('Apply Talos config to ' + node + ' [y|N] ?')]
[doc('Apply Talos config to a node')]
apply-node node *args:
    just talos render-config "{{ node }}" | talosctl -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Download Talos machine image')]
[script]
download-image version:
    export SCHEMATIC="$(just talos schematic-id)"
    gum spin --title "Downloading Talos {{ version }} ..." -- \
    curl -sfL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors \
        -o "{{ source_directory() }}/talos-{{ version }}-${SCHEMATIC:0:8}.iso" \
        "https://factory.talos.dev/image/${SCHEMATIC}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "${SCHEMATIC}"

[confirm('Reboot node ' + node + ' [y|N] ?')]
[doc('Reboot a node')]
reboot-node node:
    talosctl -n {{ node }} reboot -m powercycle

[doc('Render Talos config for a node')]
[script]
render-config node:
    export CONTROLPLANE="$(just talos machine-controller {{ node }})"
    export SCHEMATIC="$(just talos schematic-id)"
    talosctl machineconfig patch <(just template "{{ source_directory() }}/machineconfig.yaml.j2") \
        -p @<(just template "{{ source_directory() }}/nodes/{{ node }}.yaml.j2")

[doc('Fetch kubeconfig and restart controllers (use after a Talos config apply)')]
[script]
kubeconfig:
    controller="$(talosctl config info -o yaml | yq -e '.endpoints[0]')"
    talosctl kubeconfig -n "$controller" -f --force-context-name main "{{ justfile_dir() }}"
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
[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    talosctl -n "$(talosctl config info -o yaml | yq -e '.endpoints[0]')" upgrade-k8s --to {{ version }}

[confirm('Upgrade node ' + node + ' [y|N] ?')]
[doc('Upgrade Talos version on a node')]
upgrade-node node *args:
    talosctl -n "{{ node }}" upgrade -i "$(just talos machine-image)" -m powercycle --timeout=10m {{ args }}

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

[private]
schematic-id:
    curl -sX POST --data-binary @<(just template "{{ source_directory() }}/schematic.yaml.j2") "https://factory.talos.dev/schematics" | jq -r '.id'

[private]
machine-controller node:
    just template "{{ source_directory() }}/nodes/{{ node }}.yaml.j2" | yq -e 'select(.machine) | (.machine.type == "controlplane") // ""'

[private]
[script]
machine-image:
    export SCHEMATIC="$(just talos schematic-id)"
    just template "{{ source_directory() }}/machineconfig.yaml.j2" | yq -er 'select(.machine) | .machine.install.image'
