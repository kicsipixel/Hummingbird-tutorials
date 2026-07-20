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

variable "tls_certificate_ocid" {
  description = "OCID of the imported TLS certificate (leave empty until the cert is imported; the HTTPS listener is skipped until it's set)"
  type        = string
  default     = ""
}
