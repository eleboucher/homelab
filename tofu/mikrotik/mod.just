set lazy
set positional-arguments
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

tofu_dir := justfile_dir() + '/tofu/mikrotik'
op_run   := 'op run --env-file=' + tofu_dir + '/op.env --'

[doc('Initialize the working directory and download providers')]
init *args:
    cd "{{ tofu_dir }}" && {{ op_run }} tofu init "$@"

[doc('Format all .tf files')]
fmt *args:
    cd "{{ tofu_dir }}" && tofu fmt -recursive "$@"

[doc('Validate the configuration')]
validate:
    cd "{{ tofu_dir }}" && {{ op_run }} tofu validate

[doc('Show planned changes; writes plan.tfplan')]
plan *args:
    cd "{{ tofu_dir }}" && {{ op_run }} tofu plan -out=plan.tfplan "$@"

[doc('Apply the saved plan')]
apply *args:
    cd "{{ tofu_dir }}" && {{ op_run }} tofu apply "$@"

[doc('Show current state or a resource (read-only)')]
show *args:
    cd "{{ tofu_dir }}" && {{ op_run }} tofu show "$@"

[doc('Drop into an env-populated shell for ad-hoc tofu/router commands')]
shell:
    cd "{{ tofu_dir }}" && {{ op_run }} bash

[doc('Refresh state from the router (read-only)')]
refresh:
    cd "{{ tofu_dir }}" && {{ op_run }} tofu apply -refresh-only

[doc('Pass-through any tofu subcommand, e.g. just mikrotik run state list')]
run *args:
    cd "{{ tofu_dir }}" && {{ op_run }} tofu "$@"
