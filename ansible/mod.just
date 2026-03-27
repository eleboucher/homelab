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

[doc('Trigger a doco-cd deployment via the API')]
deploy ip:
    api_key=$(op read "op://kubernetes/doco-cd/api_secret") && \
    ssh "{{ ip }}" "curl --silent --fail --request POST \
      --url 'http://localhost:8080/v1/api/poll/run?wait=true' \
      --header 'content-type: application/json' \
      --header 'x-api-key: ${api_key}' \
      --data '[{\"url\": \"https://git.erwanleboucher.dev/eleboucher/homelab.git\"}]'"
