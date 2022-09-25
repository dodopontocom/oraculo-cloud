data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = 1
}

# Gets a list of all images that support a given VM Instance shape
data "oci_core_images" "supported_a1_instances_shape_images" {
  compartment_id   = var.tenancy_ocid
  shape            = "VM.Standard.A1.Flex"
  operating_system = "Canonical Ubuntu"
}

data "oci_core_image" "a1_image" {
    image_id = values({
    for opsv, details in data.oci_core_images.supported_a1_instances_shape_images.images:
    opsv => details.id if details.operating_system_version == var.ubuntu_a1_image_version })[0]
}

data "oci_objectstorage_namespace" "namespace" {
    compartment_id = var.tenancy_ocid
}

# data "oci_objectstorage_preauthrequests" "test_preauthenticated_requests" {
#     #Required
#     bucket = "tf"
#     namespace = data.oci_objectstorage_namespace.namespace.namespace

#     #Optional
#     #object_name_prefix = var.preauthenticated_request_object_name_prefix
# }
