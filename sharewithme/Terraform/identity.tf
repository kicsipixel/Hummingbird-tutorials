#---------------------------------------------------------
# Compartment
#---------------------------------------------------------
resource "oci_identity_compartment" "compartment_sharewithme" {
  compartment_id = var.tenancy_id
  description    = "Compartment for ShareWithMe project"
  name           = "ShareWithMe_Compartment"
}

#---------------------------------------------------------
# Domain
#---------------------------------------------------------
resource "oci_identity_domain" "domain_sharewithme" {
  compartment_id = oci_identity_compartment.compartment_sharewithme.id
  description    = "Domain for ShareWithMe project"
  display_name   = "ShareWithMe_Domain"
  home_region    = "eu-frankfurt-1"
  license_type   = "free"
}

#---------------------------------------------------------
# Dynamic Group
#---------------------------------------------------------
resource "oci_identity_dynamic_group" "dynamic_group_sharewithme" {
  compartment_id = var.tenancy_id
  description    = "Dynamic Group for ShareWithMe project"
  matching_rule  = "All {instance.compartment.id = '${oci_identity_compartment.compartment_sharewithme.id}'}"
  name           = "ShareWithMe_Dynamic_Group"
}

#---------------------------------------------------------
# Policies
#---------------------------------------------------------
resource "oci_identity_policy" "policy_sharewithme" {
  compartment_id = oci_identity_compartment.compartment_sharewithme.id
  description    = "Policy for ShareWithMe project"
  name           = "ShareWithMe_Policy"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.dynamic_group_sharewithme.name} to read buckets in compartment id ${oci_identity_compartment.compartment_sharewithme.id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.dynamic_group_sharewithme.name} to manage objects in compartment id ${oci_identity_compartment.compartment_sharewithme.id}"
  ]
}
