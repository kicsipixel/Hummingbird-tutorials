#---------------------------------------------------------
# VCN
#---------------------------------------------------------
resource "oci_core_vcn" "vcn_sharewithme" {
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    cidr_blocks = ["10.0.0.0/16"]
    display_name = "ShareWithMe_VCN"
}

#---------------------------------------------------------
# Public Subnet
#---------------------------------------------------------
resource "oci_core_subnet" "subnet_sharewithme" {
  compartment_id = oci_identity_compartment.compartment_sharewithme.id
  vcn_id = oci_core_vcn.vcn_sharewithme.id
  display_name = "ShareWithMe_Public_Subnet"
  cidr_block = "10.0.0.0/26"
  route_table_id = oci_core_route_table.route_table_sharewithme.id
  security_list_ids = [oci_core_security_list.security_list_sharewithme.id]
}

#---------------------------------------------------------
# Internet Gateway
#---------------------------------------------------------
resource "oci_core_internet_gateway" "internet_gateway_sharewithme" {
   #Required
   compartment_id = oci_identity_compartment.compartment_sharewithme.id
   vcn_id = oci_core_vcn.vcn_sharewithme.id
   display_name = "ShareWithMe_InternetGateway"
}

#---------------------------------------------------------
# Route Table for Public Subnet
#---------------------------------------------------------
resource "oci_core_route_table" "route_table_sharewithme" {
    #Required
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    vcn_id = oci_core_vcn.vcn_sharewithme.id
    display_name = "ShareWithMe_RouteTable"
    route_rules {
      destination = "0.0.0.0/0"
      destination_type = "CIDR_BLOCK"
      network_entity_id = oci_core_internet_gateway.internet_gateway_sharewithme.id
    }
}

#---------------------------------------------------------
# Security List for Public Subnet
#---------------------------------------------------------
resource "oci_core_security_list" "security_list_sharewithme" {
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    vcn_id = oci_core_vcn.vcn_sharewithme.id
    display_name = "ShareWithMe_SecurityList"

    # ICMP type 3, code 4 (Destination Unreachable: Fragmentation Needed) from anywhere
    ingress_security_rules {
        protocol = "1"
        source = "0.0.0.0/0"
        icmp_options {
            type = 3
            code = 4
        }
    }

    # ICMP type 3 (Destination Unreachable) from within the VCN
    ingress_security_rules {
        protocol = "1"
        source = "10.0.0.0/16"
        icmp_options {
            type = 3
        }
    }

    # HTTP (TCP 80) from anywhere
    ingress_security_rules {
        protocol = "6"
        source = "0.0.0.0/0"
        tcp_options {
            min = 80
            max = 80
        }
    }

    # HTTPS (TCP 443) from anywhere
    ingress_security_rules {
        protocol = "6"
        source = "0.0.0.0/0"
        tcp_options {
            min = 443
            max = 443
        }
    }

    # Allow all outbound traffic
    egress_security_rules {
        protocol = "all"
        destination = "0.0.0.0/0"
    }
}

#---------------------------------------------------------
# Load Balancer
#---------------------------------------------------------
resource "oci_load_balancer_load_balancer" "load_balancer_sharewithme" {
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    display_name = "ShareWithMe_LoadBalancer"
    shape = "flexible"
    subnet_ids = [oci_core_subnet.subnet_sharewithme.id]

    shape_details {
        maximum_bandwidth_in_mbps = 10
        minimum_bandwidth_in_mbps = 10
    }
}

#---------------------------------------------------------
# Load Balancer - Backend Set
#---------------------------------------------------------
resource "oci_load_balancer_backend_set" "backend_set_sharewithme" {
    load_balancer_id = oci_load_balancer_load_balancer.load_balancer_sharewithme.id
    name = "ShareWithMe_BackendSet"
    policy = "ROUND_ROBIN"

    health_checker {
        protocol = "TCP"
        port = 30080
    }
}

#---------------------------------------------------------
# Load Balancer - Listener
#---------------------------------------------------------
resource "oci_load_balancer_listener" "listener_sharewithme" {
    load_balancer_id = oci_load_balancer_load_balancer.load_balancer_sharewithme.id
    name = "ShareWithMe_Listener"
    default_backend_set_name = oci_load_balancer_backend_set.backend_set_sharewithme.name
    port = 80
    protocol = "HTTP"
}

#---------------------------------------------------------
# Load Balancer - Listener (HTTPS)
#---------------------------------------------------------
resource "oci_load_balancer_listener" "listener_sharewithme_https" {
    count = var.tls_certificate_ocid != "" ? 1 : 0

    load_balancer_id = oci_load_balancer_load_balancer.load_balancer_sharewithme.id
    name = "ShareWithMe_HTTPS_Listener"
    default_backend_set_name = oci_load_balancer_backend_set.backend_set_sharewithme.name
    port = 443
    protocol = "HTTP"

    ssl_configuration {
        certificate_ids = [var.tls_certificate_ocid]
        verify_peer_certificate = false
    }
}

#---------------------------------------------------------
# Load Balancer - Backends (one per compute instance)
#---------------------------------------------------------
resource "oci_load_balancer_backend" "backend_sharewithme_control" {
    #Required
    load_balancer_id = oci_load_balancer_load_balancer.load_balancer_sharewithme.id
    backendset_name = oci_load_balancer_backend_set.backend_set_sharewithme.name
    ip_address = oci_core_instance.instance_sharewithme_control.private_ip
    port = 30080
}

resource "oci_load_balancer_backend" "backend_sharewithme_worker" {
    #Required
    load_balancer_id = oci_load_balancer_load_balancer.load_balancer_sharewithme.id
    backendset_name = oci_load_balancer_backend_set.backend_set_sharewithme.name
    ip_address = oci_core_instance.instance_sharewithme_worker.private_ip
    port = 30080
}
