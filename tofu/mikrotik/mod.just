set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

op_run := 'op run --env-file=' + source_directory() + '/op.env --'

[doc('Initialize the working directory and download providers')]
init *args:
    cd "{{ source_directory() }}" && {{ op_run }} tofu init {{ args }}

[doc('Format all .tf files')]
fmt *args:
    cd "{{ source_directory() }}" && tofu fmt -recursive {{ args }}

[doc('Validate the configuration')]
validate:
    cd "{{ source_directory() }}" && {{ op_run }} tofu validate

[doc('Show planned changes; writes plan.tfplan')]
plan *args:
    cd "{{ source_directory() }}" && {{ op_run }} tofu plan -out=plan.tfplan {{ args }}

[confirm('Apply tofu changes to Mikrotik router [y|N] ?')]
[doc('Apply the saved plan')]
apply *args:
    cd "{{ source_directory() }}" && {{ op_run }} tofu apply {{ args }}

[doc('Show current state or a resource (read-only)')]
show *args:
    cd "{{ source_directory() }}" && {{ op_run }} tofu show {{ args }}

[doc('Drop into an env-populated shell for ad-hoc tofu/router commands')]
shell:
    cd "{{ source_directory() }}" && {{ op_run }} bash

[doc('Refresh state from the router (read-only)')]
refresh:
    cd "{{ source_directory() }}" && {{ op_run }} tofu apply -refresh-only

[doc('Pass-through any tofu subcommand, e.g. just mikrotik run state list')]
run *args:
    cd "{{ source_directory() }}" && {{ op_run }} tofu {{ args }}
