#---------------------------------------------------------
# IAM
#---------------------------------------------------------
# Compartment
output "compartment_ocid" {
  description = "OCID of the compartment"
  value       = oci_identity_compartment.compartment_sharewithme.id
}

# Domain
output "domain_status" {
  description = "The deployment status of your Identity Domain"
  value       = "Identity Domain '${oci_identity_domain.domain_sharewithme.display_name}' is ${oci_identity_domain.domain_sharewithme.state}."
}

# Dynamic Group
output "dynamic_group_status" {
  description = "The deployment status of your Dynamic Group"
  value       = "Dynamic Group '${oci_identity_dynamic_group.dynamic_group_sharewithme.name}' is ${oci_identity_dynamic_group.dynamic_group_sharewithme.state}."
}

# Policies
output "policies_status" {
  description = "The deployment status of your Policies"
  value       = "Policy '${oci_identity_policy.policy_sharewithme.name}' is ${oci_identity_policy.policy_sharewithme.state}."
}

#---------------------------------------------------------
# Networking - Public
#---------------------------------------------------------
# VCN
output "vcn_status" {
  description = "The deployment status of your VCN"
  value       = "VCN '${oci_core_vcn.vcn_sharewithme.display_name}' is ${oci_core_vcn.vcn_sharewithme.state}."
}

# Subnet
output "subnet_status" {
  description = "The deployment status of your Public Subnet"
  value       = "Subnet '${oci_core_subnet.subnet_sharewithme.display_name}' is ${oci_core_subnet.subnet_sharewithme.state}."
}

output "subnet_ocid" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.subnet_sharewithme.id
}

# Internet Gateway
output "internet_gateway_status" {
  description = "The deployment status of your Internet Gateway"
  value       = "Internet Gateway '${oci_core_internet_gateway.internet_gateway_sharewithme.display_name}' is ${oci_core_internet_gateway.internet_gateway_sharewithme.state}."
}

# Route Table
output "route_table_status" {
  description = "The deployment status of your Route Table"
  value       = "Route Table '${oci_core_route_table.route_table_sharewithme.display_name}' is ${oci_core_route_table.route_table_sharewithme.state}."
}

# Security List
output "security_list_status" {
  description = "The deployment status of your Security List"
  value       = "Security List '${oci_core_security_list.security_list_sharewithme.display_name}' is ${oci_core_security_list.security_list_sharewithme.state}."
}

# Load Balancer
output "load_balancer_status" {
  description = "The deployment status of your Load Balancer"
  value       = "Load Balancer '${oci_load_balancer_load_balancer.load_balancer_sharewithme.display_name}' is ${oci_load_balancer_load_balancer.load_balancer_sharewithme.state}."
}

output "load_balancer_public_ip" {
  description = "Public IP address of the Load Balancer"
  value       = oci_load_balancer_load_balancer.load_balancer_sharewithme.ip_address_details[0].ip_address
}

#---------------------------------------------------------
# Networking - Private
#---------------------------------------------------------
# Private Subnet
output "private_subnet_status" {
  description = "The deployment status of your Private Subnet"
  value       = "Subnet '${oci_core_subnet.private_subnet_sharewithme.display_name}' is ${oci_core_subnet.private_subnet_sharewithme.state}."
}

output "private_subnet_ocid" {
  description = "OCID of the private subnet"
  value       = oci_core_subnet.private_subnet_sharewithme.id
}

# NAT Gateway
output "nat_gateway_status" {
  description = "The deployment status of your NAT Gateway"
  value       = "NAT Gateway '${oci_core_nat_gateway.nat_gateway_sharewithme.display_name}' is ${oci_core_nat_gateway.nat_gateway_sharewithme.state}."
}

# Service Gateway
output "service_gateway_status" {
  description = "The deployment status of your Service Gateway"
  value       = "Service Gateway '${oci_core_service_gateway.service_gateway_sharewithme.display_name}' is ${oci_core_service_gateway.service_gateway_sharewithme.state}."
}

# Private Route Table
output "private_route_table_status" {
  description = "The deployment status of your Private Route Table"
  value       = "Route Table '${oci_core_route_table.private_route_table_sharewithme.display_name}' is ${oci_core_route_table.private_route_table_sharewithme.state}."
}

# Private Security List
output "private_security_list_status" {
  description = "The deployment status of your Private Security List"
  value       = "Security List '${oci_core_security_list.private_security_list_sharewithme.display_name}' is ${oci_core_security_list.private_security_list_sharewithme.state}."
}

#---------------------------------------------------------
# Compute
#---------------------------------------------------------
output "instance_control_status" {
  description = "The deployment status of your Control Compute Instance"
  value       = "Instance '${oci_core_instance.instance_sharewithme_control.display_name}' is ${oci_core_instance.instance_sharewithme_control.state}."
}

output "instance_control_private_ip" {
  description = "Private IP address of the Control Compute Instance"
  value       = oci_core_instance.instance_sharewithme_control.private_ip
}

output "instance_worker_status" {
  description = "The deployment status of your Worker Compute Instance"
  value       = "Instance '${oci_core_instance.instance_sharewithme_worker.display_name}' is ${oci_core_instance.instance_sharewithme_worker.state}."
}

output "instance_worker_private_ip" {
  description = "Private IP address of the Worker Compute Instance"
  value       = oci_core_instance.instance_sharewithme_worker.private_ip
}

#---------------------------------------------------------
# Bastion
#---------------------------------------------------------
output "bastion_status" {
  description = "The deployment status of your Bastion"
  value       = "Bastion '${oci_bastion_bastion.bastion_sharewithme.name}' is ${oci_bastion_bastion.bastion_sharewithme.state}."
}
