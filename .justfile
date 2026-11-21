#!/usr/bin/env -S just --justfile

set lazy
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

# Bootstrap Recipes
[group('Bootstrap')]
mod bootstrap "bootstrap"

# Kube Recipes
[group('Kube')]
mod kube "kubernetes"

# Talos Recipes
[group('Talos')]
mod talos "talos"

# Mikrotik Recipes
[group('Mikrotik')]
mod mikrotik 'pulumi/mikrotik'

# Mikrotik OpenTofu Recipes, kept until the Pulumi import is confirmed
[group('Mikrotik')]
mod mikrotik-tofu 'tofu/mikrotik'

# UniFi Recipes
[group('UniFi')]
mod unifi 'pulumi/unifi'

[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    minijinja-cli "{{ file }}" {{ args }} | vals eval -f -
