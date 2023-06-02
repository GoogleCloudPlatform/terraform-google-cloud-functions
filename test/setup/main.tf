/**
 * Copyright 2019 Google LLC
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

module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 14.0"

  name                    = "ci-cloud-functions"
  random_project_id       = "true"
  org_id                  = var.org_id
  folder_id               = var.folder_id
  billing_account         = var.billing_account
  default_service_account = "keep"

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
    "eventarc.googleapis.com",
    "iamcredentials.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudkms.googleapis.com",
    "bigquery.googleapis.com",
    "certificatemanager.googleapis.com",
    "sql-component.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com"
  ]
}

resource "null_resource" "generate_cert" {
  provisioner "local-exec" {
    command = <<EOT
      openssl req -x509 -newkey rsa:2048 \
        -keyout key.pem \
        -out cert.pem -days 365 \
        -subj '/CN=myswp.example.com' -nodes \
        -addext "subjectAltName=DNS:myswp.example.com"
    EOT
  }
}

data "local_file" "key" {
  filename   = "${path.module}/key.pem"
  depends_on = [null_resource.generate_cert]
}

data "local_file" "cert" {
  filename   = "${path.module}/cert.pem"
  depends_on = [null_resource.generate_cert]
}

resource "google_certificate_manager_certificate" "swp_certificate" {
  name        = "swp-certificate"
  description = "Secure Web Proxy provided certificate."
  project     = module.project.project_id
  location    = "us-west1"
  self_managed {
    pem_private_key = data.local_file.key.content
    pem_certificate = data.local_file.cert.content
  }

  depends_on = [
    module.project,
    data.local_file.cert,
    data.local_file.key
  ]
}
