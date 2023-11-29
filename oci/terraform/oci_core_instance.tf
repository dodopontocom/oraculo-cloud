resource "oci_core_instance" "instance" {
  count               = 1
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.tenancy_ocid
  display_name        = "node-${count.index}"
  shape               = "VM.Standard.E2.1.Micro"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 1
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.dev_subnet.id
    display_name              = oci_core_vcn.my_vnc.display_name
    assign_public_ip          = true
    assign_private_dns_record = true
    hostname_label            = "node-${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_image.image.image_id
    boot_volume_size_in_gbs = var.bvsize
  }
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    ### command to get oci metadata (must be inside the instance)
    ### curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata
    DARLENE1_TOKEN = var.DARLENE1_TOKEN
    TELEGRAM_ID = var.TELEGRAM_ID
  }

  timeouts {
    create = "24h"
  }

  preserve_boot_volume = false
}

locals {
  pr_key = file("~/.ssh/id_rsa")
}

resource "null_resource" "remote-exec" {
  depends_on = [oci_core_instance.instance]
  count = 2

  triggers = {
    master_id = "${element(oci_core_instance.instance.*.id, count.index)}"
  }

  provisioner "remote-exec" {
    connection {
      agent       = false
      timeout     = "24h"
      host        = "${element(oci_core_instance.instance.*.public_ip, count.index)}"
      user        = "ubuntu"
      private_key = local.pr_key
    }

    inline = [
      "curl --header \"Authorization: Bearer Oracle\" http://169.254.169.254/opc/v2/instance/metadata > /home/ubuntu/hi.txt",
      "wget https://raw.githubusercontent.com/dodopontocom/oraculo-cloud/wip/oci/terraform/bootstrap/init.sh",
      "chmod +x ./init.sh",
      "sleep 30",
      "nohup ./init.sh &",
      "sleep 5",
    ]
  }
}