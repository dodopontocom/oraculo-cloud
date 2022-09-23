output "vnc_id" {
  value = oci_core_vcn.my_vnc.id
}

output "vnc_state" {
  value = oci_core_vcn.my_vnc.state
}

output "subnet_info" {
  value = oci_core_subnet.dev_subnet.id
}

output "subnet_state" {
  value = oci_core_subnet.dev_subnet.state
}

output "instance_pub_ip" {
  value = oci_core_instance.ampere-a1-instance.public_ip
}

output "oci_identity_availability_domain" {
  value = data.oci_identity_availability_domain.ad.name
}