resource "oci_objectstorage_bucket" "terraform" {
    compartment_id = var.tenancy_ocid
    name = "tf"
    namespace = data.oci_objectstorage_namespace.namespace.namespace
    access_type = "ObjectReadWithoutList"
}

resource "oci_objectstorage_object" "tfstate" {
    bucket = oci_objectstorage_bucket.terraform.name
    #content = var.object_content
    namespace = data.oci_objectstorage_namespace.namespace.namespace
    object = "tfstate"
}

# resource "oci_objectstorage_preauthrequest" "preauthenticated_request" {
#     #Required
#     access_type = "AnyObjectReadWrite"
#     bucket = oci_objectstorage_bucket.terraform.name
#     name = "preauth"
#     namespace = data.oci_objectstorage_namespace.namespace.namespace
#     time_expires = "2040-08-15T15:52:01+00:00"

#     #Optional
#     bucket_listing_action = "ListObjects"
#     #object = oci_objectstorage_object.tfstate.object
# }