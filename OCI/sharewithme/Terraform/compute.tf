#---------------------------------------------------------
# Availability Domain and Image lookups
#---------------------------------------------------------
data "oci_identity_availability_domains" "availability_domains_sharewithme" {
  compartment_id = var.tenancy_id
}

data "oci_core_images" "ubuntu_minimal_arm_sharewithme" {
  compartment_id           = oci_identity_compartment.compartment_sharewithme.id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04 Minimal aarch64"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}


#---------------------------------------------------------
# Compute Instances - Control plane
#---------------------------------------------------------
resource "oci_core_instance" "instance_sharewithme_control" {
    #Required
    availability_domain = data.oci_identity_availability_domains.availability_domains_sharewithme.availability_domains[0].name
    fault_domain = "FAULT-DOMAIN-2"
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    display_name = "ShareWithMe_Instance_Control"
    shape = "VM.Standard.A1.Flex"

    shape_config {
        ocpus = 1
        memory_in_gbs = 12
    }

    source_details {
        source_type = "image"
        source_id = data.oci_core_images.ubuntu_minimal_arm_sharewithme.images[0].id
    }

    create_vnic_details {
        subnet_id = oci_core_subnet.private_subnet_sharewithme.id
        assign_public_ip = false
    }

    agent_config {
        plugins_config {
            name = "Bastion"
            desired_state = "ENABLED"
        }
    }

    metadata = {
        ssh_authorized_keys = var.ssh_public_key
        user_data = base64encode(file("${path.module}/scripts/ubuntu_init.sh"))
    }
}


#---------------------------------------------------------
# Compute Instances - Worker
#---------------------------------------------------------
resource "oci_core_instance" "instance_sharewithme_worker" {
    #Required
    availability_domain = data.oci_identity_availability_domains.availability_domains_sharewithme.availability_domains[0].name
    fault_domain = "FAULT-DOMAIN-3"
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    display_name = "ShareWithMe_Instance_Worker"
    shape = "VM.Standard.A1.Flex"

    shape_config {
        ocpus = 1
        memory_in_gbs = 12
    }

    source_details {
        source_type = "image"
        source_id = data.oci_core_images.ubuntu_minimal_arm_sharewithme.images[0].id
    }

    create_vnic_details {
        subnet_id = oci_core_subnet.private_subnet_sharewithme.id
        assign_public_ip = false
    }

    agent_config {
        plugins_config {
            name = "Bastion"
            desired_state = "ENABLED"
        }
    }

    metadata = {
        ssh_authorized_keys = var.ssh_public_key
        user_data = base64encode(file("${path.module}/scripts/ubuntu_init.sh"))
    }
}