# Cloud Armor module
This module allows you to create Cloud Armor policies.
Default rules are included in the module by the security/network team.
Application teams can add their own custom rules for their applications.

# Examples

## Basic example
```hcl
module "cloud-armor-simple" {
  source  = "./modules/cloud-armor-module"
  project_id = "my-project-id"
  policy_name = "default"
  application_rules = {}
}
```
## Basic example + application custom rules
```hcl
module "cloud-armor-custom" {
  source  = "./modules/cloud-armor-module"
  project_id = "my-project-id"
  policy_name = "custom-app1"
  application_rules = {
    rule1 = {
      action      = "deny(403)"
      priority    = "3000"
      expression  = "evaluatePreconfiguredExpr('xss-v33-stable')"
      description = "Cross-site scripting (Sensitivity level 2)"
    }
  }
}
```

<!-- BEGIN TFDOC -->

## Variables

| name | description | type | required | default |
|---|---|:---:|:---:|:---:|
| [policy_name](variables.tf#L17) | Name of the Cloud Armor policy. | <code>string</code> |  | default |
| [project_id](variables.tf#L22) | Project identifier. | <code>string</code> | ✓ |  |
| [description](variables.tf#L26) | Description of the Cloud Armor policy | <code>string</code> |  | default cloud Armor policy |
| [application_rules](variables.tf#L31) | Block containing the custom application rules. See examples for correct format. | <code>list(object({…}))</code> |  |  |

## Outputs

| name | description | sensitive |
|---|---|:---:|
| [security_policy_id](outputs.tf#L17) | ID of the security policy created. |  |

<!-- END TFDOC -->
