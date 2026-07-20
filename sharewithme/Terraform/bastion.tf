#---------------------------------------------------------
# Bastion
#---------------------------------------------------------
resource "oci_bastion_bastion" "bastion_sharewithme" {
    bastion_type = "STANDARD"
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    target_subnet_id = oci_core_subnet.private_subnet_sharewithme.id
    name = "ShareWithMeBastion"
    client_cidr_block_allow_list = ["0.0.0.0/0"]
    max_session_ttl_in_seconds = 10800
}
