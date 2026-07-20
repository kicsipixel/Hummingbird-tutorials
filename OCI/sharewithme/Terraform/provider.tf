terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

provider "oci" {
  region              = "eu-frankfurt-1"
  config_file_profile = "DEFAULT"
}
