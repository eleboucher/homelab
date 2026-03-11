set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

[doc('Install Ansible collections required for VPS playbook')]
install-collections:
    ansible-galaxy collection install -r "{{ justfile_dir() }}/vps/requirements.yml"

[doc('Install Pangolin on VPS and save info to 1Password')]
install ip: install-collections
    ansible-playbook -i "{{ ip }}," "{{ justfile_dir() }}/vps/playbook.yml"
