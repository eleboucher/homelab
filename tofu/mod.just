set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

tofu_dir := justfile_dir() + '/tofu'

[private]
default:
    just -l tofu

[doc('Initialize tofu configuration')]
init args:
    tofu -chdir="{{ tofu_dir }}" init {{ args }}

[doc('Plan tofu-managed infrastructure changes')]
plan args:
    tofu -chdir="{{ tofu_dir }}" plan {{ args }}

[doc('Apply tofu configuration')]
apply args:
    tofu -chdir="{{ tofu_dir }}" apply {{ args }}

[doc('Destroy tofu-managed infrastructure')]
destroy args:
    tofu -chdir="{{ tofu_dir }}" destroy {{ args }}
