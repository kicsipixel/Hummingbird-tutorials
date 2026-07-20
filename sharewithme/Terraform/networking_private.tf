#---------------------------------------------------------
# Private Subnet
#---------------------------------------------------------
resource "oci_core_subnet" "private_subnet_sharewithme" {
  compartment_id = oci_identity_compartment.compartment_sharewithme.id
  vcn_id = oci_core_vcn.vcn_sharewithme.id
  display_name = "ShareWithMe_Private_Subnet"
  cidr_block = "10.0.1.0/26"
  route_table_id = oci_core_route_table.private_route_table_sharewithme.id
  security_list_ids = [oci_core_security_list.private_security_list_sharewithme.id]
  prohibit_public_ip_on_vnic = true
}

#---------------------------------------------------------
# NAT Gateway
#---------------------------------------------------------
resource "oci_core_nat_gateway" "nat_gateway_sharewithme" {
    #Required
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    vcn_id = oci_core_vcn.vcn_sharewithme.id
    display_name = "ShareWithMe_NatGateway"
}

#---------------------------------------------------------
# Service Gateway (Object Storage and other OCI services)
#---------------------------------------------------------
data "oci_core_services" "all_services_sharewithme" {
    filter {
        name = "name"
        values = ["All .* Services In Oracle Services Network"]
        regex = true
    }
}

resource "oci_core_service_gateway" "service_gateway_sharewithme" {
    #Required
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    vcn_id = oci_core_vcn.vcn_sharewithme.id
    display_name = "ShareWithMe_ServiceGateway"
    services {
        service_id = data.oci_core_services.all_services_sharewithme.services[0].id
    }
}

#---------------------------------------------------------
# Private Route Table
#---------------------------------------------------------
resource "oci_core_route_table" "private_route_table_sharewithme" {
    #Required
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    vcn_id = oci_core_vcn.vcn_sharewithme.id
    display_name = "ShareWithMe_Private_RouteTable"
    route_rules {
      destination = "0.0.0.0/0"
      destination_type = "CIDR_BLOCK"
      network_entity_id = oci_core_nat_gateway.nat_gateway_sharewithme.id
    }
    route_rules {
      destination = data.oci_core_services.all_services_sharewithme.services[0].cidr_block
      destination_type = "SERVICE_CIDR_BLOCK"
      network_entity_id = oci_core_service_gateway.service_gateway_sharewithme.id
    }
}

#---------------------------------------------------------
# Security List for Private Subnet
#---------------------------------------------------------
resource "oci_core_security_list" "private_security_list_sharewithme" {
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    vcn_id = oci_core_vcn.vcn_sharewithme.id
    display_name = "ShareWithMe_Private_SecurityList"

    # Allow all inbound traffic from public subnet
    ingress_security_rules {
        protocol = "all"
        source = "10.0.0.0/26"
    }

    # SSH from the Bastion endpoint (VCN-internal only) - TCP port 22
    ingress_security_rules {
        protocol = "6"
        source = "10.0.0.0/16"
        tcp_options {
            min = 22
            max = 22
        }
    }

    # K3s API server - TCP port 6443
    ingress_security_rules {
        protocol = "6"
        source = "10.0.0.0/16"
        tcp_options {
            min = 6443
            max = 6443
        }
    }

    # Pod-to-Pod communication (Flannel VXLAN) - UDP port 8472
    ingress_security_rules {
        protocol = "17"
        source = "10.0.0.0/16"
        udp_options {
            min = 8472
            max = 8472
        }
    }

    # Allow all outbound traffic
    egress_security_rules {
        protocol = "all"
        destination = "0.0.0.0/0"
    }
}

