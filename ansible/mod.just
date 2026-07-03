set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[doc('Install Ansible collections required for VPS playbook')]
install-collections:
    ansible-galaxy collection install -r "{{ source_directory() }}/requirements.yml"

[confirm('Install Pangolin on ' + ip + ' [y|N] ?')]
[doc('Install Pangolin on VPS and save info to 1Password')]
install ip: install-collections
    ansible-playbook -i "{{ ip }}," "{{ source_directory() }}/playbook.yml"

[confirm('Trigger doco-cd deployment on ' + ip + ' [y|N] ?')]
[doc('Trigger a doco-cd deployment via the API')]
deploy ip:
    api_key=$(vals get "ref+op://kubernetes/doco-cd/api_secret") && \
    ssh "{{ ip }}" "curl --silent --fail --request POST \
      --url 'http://localhost:8080/v1/api/poll/run?wait=true' \
      --header 'content-type: application/json' \
      --header 'x-api-key: ${api_key}' \
      --data '[{\"url\": \"https://github.com/eleboucher/homelab.git\"}]'"
