variable "region" {
  description = "OCI region"
  type        = string
}

variable "config_file_profile" {
  description = "OCI CLI profile name"
  type        = string
}

variable "tenancy_id" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for the compute instances (OpenSSH format, set in terraform.tfvars)"
  type        = string
}
