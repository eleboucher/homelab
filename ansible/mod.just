set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

ansible_dir := justfile_dir() + '/ansible'

[doc('Install Ansible collections required for VPS playbook')]
install-collections:
    ansible-galaxy collection install -r "{{ ansible_dir }}/requirements.yml"

[doc('Install Pangolin on VPS and save info to 1Password')]
install ip: install-collections
    ansible-playbook -i "{{ ip }}," "{{ ansible_dir }}/playbook.yml"

[doc('Emergency: SCP compose file to VPS and run docker compose up directly (bypasses doco-cd/git)')]
deploy-direct ip:
    #!/usr/bin/env bash
    set -euo pipefail
    tmpdir=$(mktemp -d)
    trap "rm -rf $tmpdir" EXIT
    printf '%s\n' \
        "OVH_APPLICATION_KEY=$(op read 'op://kubernetes/ovh/OVH_APPLICATION_KEY')" \
        "OVH_APPLICATION_SECRET=$(op read 'op://kubernetes/ovh/OVH_APPLICATION_SECRET')" \
        "OVH_CONSUMER_KEY=$(op read 'op://kubernetes/ovh/OVH_CONSUMER_KEY')" \
        "PANGOLIN_SECRET=$(op read 'op://kubernetes/pangolin/server_secret')" \
        "MAXMIND_ACCOUNT_ID=$(op read 'op://kubernetes/pangolin/maxmind_account_id')" \
        "MAXMIND_LICENSE_KEY=$(op read 'op://kubernetes/pangolin/maxmind_key')" \
        "CROWDSEC_API_KEY=$(op read 'op://kubernetes/pangolin/crowdsec_api_key')" \
        "ANUBIS_ED25519_PRIVATE_KEY_HEX=$(op read 'op://kubernetes/anubis/ED25519_PRIVATE_KEY_HEX')" \
        > "$tmpdir/.env"
    deploy_dir="/var/lib/docker/volumes/doco-cd_data/_data/git.erwanleboucher.dev/eleboucher/homelab/docker/vps/01-pangolin"
    scp "$tmpdir/.env" "{{ ip }}:/tmp/.pangolin.env"
    scp "{{ justfile_directory() }}/docker/vps/01-pangolin/docker-compose.yml" "{{ ip }}:/tmp/pangolin-compose.yml"
    ssh "{{ ip }}" "sudo mv /tmp/.pangolin.env $deploy_dir/.env && sudo mv /tmp/pangolin-compose.yml $deploy_dir/docker-compose.yml && sudo bash -c \"cd $deploy_dir && docker compose down --remove-orphans && docker compose up -d\""

[doc('Trigger a doco-cd deployment via the API')]
deploy ip:
    api_key=$(op read "op://kubernetes/doco-cd/api_secret") && \
    ssh "{{ ip }}" "curl --silent --fail --request POST \
      --url 'http://localhost:8080/v1/api/poll/run?wait=true' \
      --header 'content-type: application/json' \
      --header 'x-api-key: ${api_key}' \
      --data '[{\"url\": \"https://git.erwanleboucher.dev/eleboucher/homelab.git\"}]'"
