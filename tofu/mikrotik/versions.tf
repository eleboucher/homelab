terraform {
  required_version = ">= 1.10.0"

  required_providers {
    routeros = {
      source  = "terraform-routeros/routeros"
      version = "~> 1.99"
    }
  }

  backend "s3" {
    bucket = "opentofu-homelab"
    key    = "mikrotik/terraform.tfstate"

    endpoints = {
      s3 = "https://s3.rbx.io.cloud.ovh.net"
    }
    region = "rbx"

    encrypt = true

    # OVH S3 doesn't implement conditional PUTs, native locking would fail.
    use_lockfile = false

    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    skip_metadata_api_check     = true
  }
}
