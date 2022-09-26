resource "oci_core_vcn" "my_vnc" {
  cidr_block     = "172.16.0.0/20"
  compartment_id = var.tenancy_ocid
  display_name   = var.vcn_name
  dns_label      = "myvnc"
  freeform_tags = {
    "environment" = "dev"
  }
}

resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = var.tenancy_ocid
  display_name   = "InternetGateway"
  vcn_id         = oci_core_vcn.my_vnc.id
}

resource "oci_core_default_route_table" "default_route_table" {
  manage_default_resource_id = oci_core_vcn.my_vnc.default_route_table_id
  display_name               = "DefaultRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
  }
}