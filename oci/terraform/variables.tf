variable "region" {}
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "vcn_name" {}
#variable "fingerprint" {}
#variable "private_key_path" {}
variable "bucket_name" {
    default = "tfstate-learn-terraform"
}

variable "ubuntu_image_version" {
    default = "22.04"
}
variable "ssh_public_key" {}
variable "DARLENE1_TOKEN" {}
variable "TELEGRAM_ID" {}
variable "bvsize" {}