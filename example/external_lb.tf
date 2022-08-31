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

resource "google_folder" "demo" {
  display_name = var.prefix
  parent       = "organizations/${var.organization_id}"
}

module "project" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project"
  name            = "project-demo"
  parent          = google_folder.demo.name
  prefix          = var.prefix
  billing_account = var.billing_account
  services        = var.project_services
}

module "vpc-prod" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc"
  project_id = module.project.project_id
  name       = "vpc-prod"
  subnets = [
    {
      ip_cidr_range      = "10.0.0.0/24"
      name               = "subnet-prod-1"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
}

# Firewall Rule for health checks
resource "google_compute_firewall" "hc-firewall" {
  name    = "health-checks"
  project = module.project.project_id
  network = module.vpc-prod.self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

module "nat-prod" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  project_id     = module.project.project_id
  region         = var.region
  name           = "nat-prod"
  router_network = module.vpc-prod.self_link
}

# instance template
resource "google_compute_instance_template" "instance_template" {
  project      = module.project.project_id
  name         = "l7-xlb-mig-template"
  machine_type = "e2-small"
  tags         = ["http-server"]

  network_interface {
    network    = module.vpc-prod.self_link
    subnetwork = module.vpc-prod.subnet_self_links["${var.region}/subnet-prod-1"]
  }
  disk {
    source_image = "debian-cloud/debian-10"
    auto_delete  = true
    boot         = true
  }

  # install nginx and serve a simple web page
  metadata = {
    startup-script = <<-EOF1
      #! /bin/bash
      set -euo pipefail

      export DEBIAN_FRONTEND=noninteractive
      sudo apt-get update
      sudo apt-get install -y nginx-light jq

      NAME=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/hostname")
      IP=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip")
      METADATA=$(curl -f -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/?recursive=True" | jq 'del(.["startup-script"])')

      cat <<EOF > /var/www/html/index.html
      <pre>
      Name: $NAME
      IP: $IP
      Metadata: $METADATA
      </pre>
      EOF
    EOF1
  }
  lifecycle {
    create_before_destroy = true
  }
}

# MIG
resource "google_compute_region_instance_group_manager" "mig" {
  project = module.project.project_id
  name    = "l7-xlb-mig1"
  region  = var.region
  version {
    instance_template = google_compute_instance_template.instance_template.id
    name              = "primary"
  }
  base_instance_name = "vm"
  target_size        = 2
  named_port {
    name = "http"
    port = 80
  }
}

# External LB with Simple Cloud Armor policy (see cloud_armor_policies.tf)
module "gce-lb-http" {
  source            = "GoogleCloudPlatform/lb-http/google"
  name              = "l7-xlb-demo"
  project           = module.project.project_id
  firewall_networks = [module.vpc-prod.self_link]

  backends = {
    default = {
      description                     = null
      protocol                        = "HTTP"
      port                            = 80
      port_name                       = "http"
      timeout_sec                     = 10
      connection_draining_timeout_sec = null
      enable_cdn                      = false
      security_policy                 = module.cloud-armor-simple.security_policy_id
      session_affinity                = null
      affinity_cookie_ttl_sec         = null
      custom_request_headers          = null
      custom_response_headers         = null

      health_check = {
        check_interval_sec  = null
        timeout_sec         = null
        healthy_threshold   = null
        unhealthy_threshold = null
        request_path        = "/"
        port                = 80
        host                = null
        logging             = null
      }

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          group                        = google_compute_region_instance_group_manager.mig.instance_group
          balancing_mode               = null
          capacity_scaler              = null
          description                  = null
          max_connections              = null
          max_connections_per_instance = null
          max_connections_per_endpoint = null
          max_rate                     = null
          max_rate_per_instance        = null
          max_rate_per_endpoint        = null
          max_utilization              = null
        }
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = ""
        oauth2_client_secret = ""
      }
    }
  }
}

# MIG 2
resource "google_compute_region_instance_group_manager" "mig2" {
  project = module.project.project_id
  name    = "l7-xlb-mig2"
  region  = var.region
  version {
    instance_template = google_compute_instance_template.instance_template.id
    name              = "primary"
  }
  base_instance_name = "vm"
  target_size        = 2
  named_port {
    name = "http"
    port = 80
  }
}

# External LB with Custom Cloud Armor policy (see cloud_armor_policies.tf)
module "gce-lb-http2" {
  source            = "GoogleCloudPlatform/lb-http/google"
  name              = "l7-xlb-demo2"
  project           = module.project.project_id
  firewall_networks = [module.vpc-prod.self_link]

  backends = {
    default = {
      description                     = null
      protocol                        = "HTTP"
      port                            = 80
      port_name                       = "http"
      timeout_sec                     = 10
      connection_draining_timeout_sec = null
      enable_cdn                      = false
      security_policy                 = module.cloud-armor-custom.security_policy_id
      session_affinity                = null
      affinity_cookie_ttl_sec         = null
      custom_request_headers          = null
      custom_response_headers         = null

      health_check = {
        check_interval_sec  = null
        timeout_sec         = null
        healthy_threshold   = null
        unhealthy_threshold = null
        request_path        = "/"
        port                = 80
        host                = null
        logging             = null
      }

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          group                        = google_compute_region_instance_group_manager.mig2.instance_group
          balancing_mode               = null
          capacity_scaler              = null
          description                  = null
          max_connections              = null
          max_connections_per_instance = null
          max_connections_per_endpoint = null
          max_rate                     = null
          max_rate_per_instance        = null
          max_rate_per_endpoint        = null
          max_utilization              = null
        }
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = ""
        oauth2_client_secret = ""
      }
    }
  }
}
