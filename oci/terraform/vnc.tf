resource "oci_core_vcn" "internal" {
  dns_label      = "internal"
  cidr_block     = "172.16.0.0/20"
  compartment_id = var.tenancy_ocid
  display_name   = var.vcn_name
  freeform_tags = {
    "environment" = "dev"
  }
}

resource "oci_core_subnet" "dev" {
  vcn_id                      = oci_core_vcn.internal.id
  cidr_block                  = "172.16.0.0/24"
  compartment_id              = var.tenancy_ocid
  display_name                = "dev-subnet"
  prohibit_public_ip_on_vnic  = true
  dns_label                   = "dev"
}