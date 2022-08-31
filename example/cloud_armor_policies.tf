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

module "cloud-armor-simple" {
  source            = "../modules/cloud-armor-module"
  project_id        = module.project.project_id
  policy_name       = "default"
  application_rules = {}
}

module "cloud-armor-custom" {
  source      = "../modules/cloud-armor-module"
  project_id  = module.project.project_id
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