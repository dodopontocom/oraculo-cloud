output "vnc_id" {
    description = "Some information about created VCN"
    value = oci_core_vcn.internal.id
}

output "vnc_state" {
    description = "Some information about created VCN"
    value = oci_core_vcn.internal.state
}

output "subnet_info" {
    description = "Some information about created VCN"
    value = oci_core_subnet.dev.id
}

output "subnet_state" {
    description = "Some information about created VCN"
    value = oci_core_subnet.dev.state
}