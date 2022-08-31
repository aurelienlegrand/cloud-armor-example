/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
 resource "google_compute_security_policy" "policy" {
  project     = var.project_id
  name        = var.policy_name
  description = var.description

  # This block implements the custom application rules, added via the "application_rules" variable
  dynamic "rule" {
    for_each = var.application_rules
    content {
      description = rule.value.description
      action      = rule.value.action
      priority    = rule.value.priority
      match {
        expr {
          expression = rule.value.expression
        }
      }
    }
  }

  # These next rules are "generic rules", managed by the security team that every application should implement
  # Feel free to adapt these rules for your organization / workload
  # See all existing Cloud Armor pre-configured rules here: https://cloud.google.com/armor/docs/rule-tuning#preconfigured_rules
  rule {
    action   = "deny(403)"
    priority = "800"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable', ['owasp-crs-v030001-id942421-sqli', 'owasp-crs-v030001-id942432-sqli'])"
      }
    }
    description = "SQL Injection (level 3)"
  }

  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('cve-canary')"
      }
    }
    description = "Log 4J CVE rule"
  }

  rule {
    action   = "deny(403)"
    priority = "2000000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["83.159.106.226/32"]
      }
    }
    description = "Block specific IPv4 address"
  }

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule"
  }
}