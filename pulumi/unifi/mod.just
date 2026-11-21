set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

op_run := 'op run --env-file=' + source_directory() + '/op.env --'

[doc('Install dependencies and generate the provider SDK')]
install:
    cd "{{ source_directory() }}" && pulumi install

[doc('Select the main stack, creating it on first use')]
init:
    cd "{{ source_directory() }}" && {{ op_run }} pulumi stack select --create main

[doc('Show planned changes')]
preview *args:
    cd "{{ source_directory() }}" && {{ op_run }} pulumi preview --diff {{ args }}

[confirm('Apply Pulumi changes to the UniFi gateway [y|N] ?')]
[doc('Apply changes')]
up *args:
    cd "{{ source_directory() }}" && {{ op_run }} pulumi up {{ args }}

[doc('Refresh state from the device (read-only on the device)')]
refresh:
    cd "{{ source_directory() }}" && {{ op_run }} pulumi refresh

[doc('Adopt the default LAN the gateway ships with (state only)')]
import-lan:
    cd "{{ source_directory() }}" && {{ op_run }} pulumi import --protect=false --generate-code=false 'unifi:index/network:Network' lan name=Default

[doc('Pass-through any pulumi subcommand, e.g. just unifi run stack ls')]
run *args:
    cd "{{ source_directory() }}" && {{ op_run }} pulumi {{ args }}
