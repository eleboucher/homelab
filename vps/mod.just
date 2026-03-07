set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

[doc('Install Pangolin on VPS and save info to 1Password')]
install ip:
    ansible-playbook -i "{{ ip }}," "{{ justfile_dir() }}/vps/playbook.yml"

[doc('Save Newt site credentials to 1Password (run after creating a site in the Pangolin dashboard)')]
save-newt ip newt_id newt_secret server_url:
    op item edit pangolin --vault kubernetes \
        "newt_id={{ newt_id }}" \
        "newt_secret={{ newt_secret }}" \
        "vps_ip={{ ip }}" \
        "server_url={{ server_url }}" < /dev/null
    just log info "Saved to 1Password: pangolin.newt_id + pangolin.newt_secret + pangolin.vps_ip + pangolin.server_url"
