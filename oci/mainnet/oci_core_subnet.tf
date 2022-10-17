resource "oci_core_subnet" "dev_subnet" {
  availability_domain        = data.oci_identity_availability_domain.ad.name
  vcn_id                     = oci_core_vcn.my_vnc.id
  cidr_block                 = "172.16.0.0/24"
  compartment_id             = var.tenancy_ocid
  display_name               = "dev-subnet"
  prohibit_public_ip_on_vnic = false
  dns_label                  = "mysubnet"
  #security_list_ids          = [oci_core_vcn.my_vnc.default_security_list_id]
  #route_table_id             = oci_core_vcn.my_vnc.default_route_table_id
  #dhcp_options_id            = oci_core_vcn.my_vnc.default_dhcp_options_id
}
