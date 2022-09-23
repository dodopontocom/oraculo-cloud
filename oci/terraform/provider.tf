terraform {
  required_version = "~> 1.3.0"
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  #   fingerprint      = var.fingerprint
  #   private_key_path = var.private_key_path
  auth                = "SecurityToken"
  config_file_profile = "learn-terraform"
  region              = var.region
}
