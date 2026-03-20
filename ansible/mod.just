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
