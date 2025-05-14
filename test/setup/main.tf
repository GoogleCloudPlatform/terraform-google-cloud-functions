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

resource "random_id" "folder-rand" {
  byte_length = 2
}

resource "google_folder" "ci-iam-folder" {
  display_name = "ci-cloud-functions-${random_id.folder-rand.hex}"
  parent       = "folders/${var.folder_id}"
}

module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name                    = "ci-cloud-functions"
  random_project_id       = "true"
  org_id                  = var.org_id
  folder_id               = google_folder.ci-iam-folder.id
  billing_account         = var.billing_account
  default_service_account = "keep"
  deletion_policy         = "DELETE"

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
