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
  value = oci_core_instance.ampere-a1-instance.*.public_ip
}

output "oci_identity_availability_domain" {
  value = data.oci_identity_availability_domain.ad.name
}

output "image_list_for_a1" {
    value = data.oci_core_images.supported_a1_instances_shape_images.images[0]["display_name"]
}

output "image_list_for_a1_id" {
    value = data.oci_core_images.supported_a1_instances_shape_images.images[0]["operating_system_version"]
}

output "a1_image_id" {
  value = values({
    for opsv, details in data.oci_core_images.supported_a1_instances_shape_images.images:
    opsv => details.id if details.operating_system_version == "20.04" })[0]
}

output "namespace_bucket" {
    value = data.oci_objectstorage_namespace.namespace
}

# output "preauth_url" {
#   value = oci_objectstorage_preauthrequest.preauthenticated_request
# }