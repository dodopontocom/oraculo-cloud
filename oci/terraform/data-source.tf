data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = 1
}

# Gets a list of all images that support a given VM Instance shape
data "oci_core_images" "supported_instances_shape_images" {
  compartment_id   = var.tenancy_ocid
  shape            = "VM.Standard.E2.1.Micro"
  operating_system = "Canonical Ubuntu"
}

data "oci_core_image" "image" {
  image_id = values({
  for opsv, details in data.oci_core_images.supported_instances_shape_images.images:
  opsv => details.id if details.operating_system_version == var.ubuntu_image_version })[0]
}

data "oci_objectstorage_namespace" "namespace" {
    compartment_id = var.tenancy_ocid
}