resource "oci_core_instance" "ampere-a1-instance" {
  count               = 2
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.tenancy_ocid
  display_name        = "preprod-cardano-node-${count.index}"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.dev_subnet.id
    display_name              = oci_core_vcn.my_vnc.display_name
    assign_public_ip          = true
    assign_private_dns_record = true
    hostname_label            = "ampere-node-${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_image.a1_image.image_id
  }
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    ### command to get oci metadata (must be inside the instance)
    ### curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata
    COLD_PAY_ADDR = var.COLD_PAY_ADDR
    DARLENE1_TOKEN = var.DARLENE1_TOKEN
    TELEGRAM_ID = var.TELEGRAM_ID
  }

  timeouts {
    create = "24h"
  }
}

locals {
  pr_key = file("~/.ssh/id_rsa")
}

resource "null_resource" "remote-exec" {
  depends_on = [oci_core_instance.ampere-a1-instance]
  count = 2

  triggers = {
    master_id = "${element(oci_core_instance.ampere-a1-instance.*.id, count.index)}"
  }

  provisioner "remote-exec" {
    connection {
      agent       = false
      timeout     = "48h"
      host        = "${element(oci_core_instance.ampere-a1-instance.*.public_ip, count.index)}"
      user        = "ubuntu"
      private_key = local.pr_key
    }

    inline = [
      "curl --header \"Authorization: Bearer Oracle\" http://169.254.169.254/opc/v2/instance/metadata > /home/ubuntu/hi.txt",
      "wget https://raw.githubusercontent.com/dodopontocom/oraculo-cloud/wip/oci/terraform/bootstrap/init.sh",
      "chmod +x ./init.sh",
      "nohup ./init.sh &",
      "sleep 5",
    ]
  }
}