/**
 * Copyright 2023 Google LLC
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

resource "google_project_service_identity" "compute_identity_sa" {
  provider = google-beta

  project = module.secure_harness.serverless_project_ids[0]
  service = "compute.googleapis.com"
}

module "compute_service_account" {
  source     = "terraform-google-modules/service-accounts/google"
  version    = "~> 4.0"
  project_id = module.secure_harness.serverless_project_ids[0]
  names      = ["sa-compute-instance"]
}

resource "google_project_iam_member" "service_account_roles" {
  for_each = toset(["roles/compute.instanceAdmin.v1", "roles/logging.logWriter", "roles/monitoring.metricWriter", "roles/iam.serviceAccountTokenCreator"])
  project  = module.secure_harness.serverless_project_ids[0]
  member   = "serviceAccount:${module.compute_service_account.email}"
  role     = each.value

  depends_on = [module.compute_service_account]
}

data "google_project" "serverless_project_id" {
  project_id = module.secure_harness.serverless_project_ids[0]
}

resource "google_service_account_iam_member" "service_account_user" {
  service_account_id = module.compute_service_account.service_account.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.serverless_project_id.number}@compute-system.iam.gserviceaccount.com"

  depends_on = [google_project_iam_member.service_account_roles]
}

resource "google_compute_instance" "internal_server" {
  name           = local.webserver_instance
  project        = module.secure_harness.serverless_project_ids[0]
  zone           = local.zone
  machine_type   = "e2-small"
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  tags                    = ["https-server", "allow-google-apis"]
  metadata_startup_script = replace(file("${abspath(path.module)}/web_server/internal_server_setup.sh"), "!PROXY_IP!", local.proxy_ip)

  network_interface {
    subnetwork         = module.secure_harness.service_subnet[0]
    network_ip         = local.network_ip
    subnetwork_project = module.secure_harness.network_project_id[0]
  }

  service_account {
    email  = module.compute_service_account.email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_service_account_iam_member.service_account_user,
    module.secure_harness,
    module.secure_web_proxy
  ]
}

module "internal_server_firewall_rule" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 11.0"

  project_id   = module.secure_harness.network_project_id[0]
  network_name = module.secure_harness.service_vpc[0].network.name

  rules = [{
    name        = "fw-e-shared-restricted-internal-server"
    description = "Allow Cloud Function to connect in Internal Server using the private IP"
    direction   = "EGRESS"
    priority    = 100

    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
    deny = []
    allow = [{
      protocol = "tcp"
      ports    = ["8000"]
    }]

    ranges      = ["10.0.0.0/28"]
    target_tags = ["allow-google-apis", "vpc-connector"]
  }]
}
