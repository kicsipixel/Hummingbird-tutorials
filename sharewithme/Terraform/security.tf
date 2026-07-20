#---------------------------------------------------------
# Web Application Firewall
#---------------------------------------------------------
#---------------------------------------------------------
# Look up OCI-managed OWASP protection capabilities
#---------------------------------------------------------
data "oci_waf_protection_capabilities" "protection_capabilities_sharewithme" {
  compartment_id    = oci_identity_compartment.compartment_sharewithme.id
  group_tag         = "OWASP"
  is_latest_version = true
}

#---------------------------------------------------------
# WAF Policy
#---------------------------------------------------------
resource "oci_waf_web_app_firewall_policy" "waf_policy_sharewithme" {
    compartment_id = oci_identity_compartment.compartment_sharewithme.id
    display_name   = "ShareWithMe_WAF_Policy"

    actions {
        name = "allow"
        type = "ALLOW"
    }

    actions {
        name = "block"
        type = "RETURN_HTTP_RESPONSE"
        code = 403
        body {
            type = "STATIC_TEXT"
            text = "Request blocked by ShareWithMe WAF"
        }
    }

    # OWASP-style protection: SQLi, XSS, and the rest of the managed rule set
    request_protection {
        rules {
            type        = "PROTECTION"
            name        = "owasp_protection"
            action_name = "block"

            dynamic "protection_capabilities" {
                for_each = data.oci_waf_protection_capabilities.protection_capabilities_sharewithme.protection_capability_collection[0].items
                content {
                    key     = protection_capabilities.value.key
                    version = protection_capabilities.value.version
                }
            }
        }
    }

    # Basic DDoS mitigation: cap requests per client
    request_rate_limiting {
        rules {
            type        = "REQUEST_RATE_LIMITING"
            name        = "rate_limit"
            action_name = "block"

            configurations {
                period_in_seconds          = 60
                requests_limit             = 300
                action_duration_in_seconds = 60
            }
        }
    }

    request_access_control {
        default_action_name = "allow"
    }
}

#---------------------------------------------------------
# Attach the policy to the load balancer
#---------------------------------------------------------
resource "oci_waf_web_app_firewall" "waf_sharewithme" {
    compartment_id             = oci_identity_compartment.compartment_sharewithme.id
    backend_type               = "LOAD_BALANCER"
    load_balancer_id           = oci_load_balancer_load_balancer.load_balancer_sharewithme.id
    web_app_firewall_policy_id = oci_waf_web_app_firewall_policy.waf_policy_sharewithme.id
    display_name               = "ShareWithMe_WAF"
}
