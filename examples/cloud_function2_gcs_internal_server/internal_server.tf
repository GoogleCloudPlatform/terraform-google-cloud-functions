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

locals {
  network_ip         = "10.0.8.3"
  subnetwork_name    = "subnet2" #set as variable
  webserver_instance = "webserver"
}


resource "google_project_service_identity" "compute_identity_sa" {
  provider = google-beta

  project = var.project_id
  service = "compute.googleapis.com"
}

module "compute_service_account" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "~> 3.0"
  project_id = var.project_id
  names      = ["sa-compute-instance"]
}

resource "google_project_iam_member" "service_account_roles" {
  project = var.project_id
  member  = "serviceAccount:${module.compute_service_account.email}"
  role    = "roles/compute.instanceAdmin.v1"

  depends_on = [module.compute_service_account]
}

data "google_project" "serverless_project_id" { #change name
  project_id = var.project_id
}

resource "google_service_account_iam_member" "service_account_user" {
  service_account_id = module.compute_service_account.service_account.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.serverless_project_id.number}@compute-system.iam.gserviceaccount.com"

  depends_on = [google_project_iam_member.service_account_roles]
}

resource "null_resource" "open_firewall" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = <<EOF
 ${abspath(path.module)}/web_server/open_firewall.sh \
    ${var.project_id}
EOF
  }
}

resource "google_compute_instance" "internal_server" {
  name = local.webserver_instance
  project        = var.project_id
  zone           = var.zone
  machine_type   = "n1-standard-1" #change to micro
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  tags                    = ["https-server"]
  metadata_startup_script = file("${abspath(path.module)}/web_server/internal_server_setup.sh")

  network_interface {
    subnetwork = local.subnetwork_name
    network_ip = local.network_ip
    subnetwork_project = var.project_id
  }

  service_account {
    email  = module.compute_service_account.email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_service_account_iam_member.service_account_user,
    null_resource.open_firewall
  ]
}

# resource "null_resource" "close_firewall" {
#   triggers = {
#     always_run = "${timestamp()}"
#   }
#   provisioner "local-exec" {
#     command = <<EOF
#  ${abspath(path.module)}/web_server/close_firewall.sh \
#     ${var.project_id} \
#     ${local.webserver_instance}
# EOF
#   }
#   depends_on = [
#     google_compute_instance.internal_server
#   ]
# }