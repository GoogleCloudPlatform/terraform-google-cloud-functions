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


module "cloud_serverless_network" {
  source  = "GoogleCloudPlatform/cloud-run/google//modules/secure-serverless-net"
  version = "~> 0.21.5"

  connector_name            = var.connector_name
  subnet_name               = var.subnet_name
  enable_load_balancer_fw   = "false"
  location                  = var.location
  vpc_project_id            = var.vpc_project_id
  serverless_project_id     = var.serverless_project_id
  shared_vpc_name           = var.shared_vpc_name
  connector_on_host_project = false
  ip_cidr_range             = var.ip_cidr_range
  create_subnet             = var.create_subnet
  resource_names_suffix     = var.resource_names_suffix

  serverless_service_identity_email = google_project_service_identity.cloudfunction_sa.email
}

data "google_service_account" "cloud_serverless_sa" {
  account_id = var.service_account_email
}

resource "google_service_account_iam_member" "identity_service_account_user" {
  service_account_id = data.google_service_account.cloud_serverless_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_project_service_identity.cloudfunction_sa.email}"
}

resource "google_project_service_identity" "eventarc_sa" {
  provider = google-beta

  project = var.serverless_project_id
  service = "eventarc.googleapis.com"
}

resource "google_project_service_identity" "cloudfunction_sa" {
  provider = google-beta

  project = var.serverless_project_id
  service = "cloudfunctions.googleapis.com"
}

resource "google_project_service_identity" "artifact_sa" {
  provider = google-beta

  project = var.serverless_project_id
  service = "artifactregistry.googleapis.com"
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.serverless_project_id
}

resource "google_project_service_identity" "pubsub_sa" {
  provider = google-beta

  project = var.serverless_project_id
  service = "pubsub.googleapis.com"
}

resource "time_sleep" "wait_service_identity_propagation" {
  create_duration = var.time_to_wait_service_identity_propagation

  depends_on = [
    google_project_service_identity.artifact_sa,
    google_project_service_identity.pubsub_sa,
    google_project_service_identity.cloudfunction_sa,
    google_project_service_identity.eventarc_sa
  ]
}

module "cloud_function_security" {
  source = "../secure-cloud-function-security"

  kms_project_id        = var.kms_project_id
  location              = var.location
  serverless_project_id = var.serverless_project_id
  prevent_destroy       = var.prevent_destroy
  key_name              = var.key_name
  keyring_name          = var.keyring_name
  key_rotation_period   = var.key_rotation_period
  key_protection_level  = var.key_protection_level
  policy_for            = var.policy_for
  folder_id             = var.folder_id
  organization_id       = var.organization_id
  groups                = var.groups

  encrypters = [
    "serviceAccount:${google_project_service_identity.cloudfunction_sa.email}",
    "serviceAccount:${var.service_account_email}",
    "serviceAccount:${google_project_service_identity.artifact_sa.email}",
    "serviceAccount:${google_project_service_identity.eventarc_sa.email}",
    "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}",
    "serviceAccount:${google_project_service_identity.pubsub_sa.email}"
  ]

  decrypters = [
    "serviceAccount:${google_project_service_identity.cloudfunction_sa.email}",
    "serviceAccount:${var.service_account_email}",
    "serviceAccount:${google_project_service_identity.artifact_sa.email}",
    "serviceAccount:${google_project_service_identity.eventarc_sa.email}",
    "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}",
    "serviceAccount:${google_project_service_identity.pubsub_sa.email}"
  ]

  depends_on = [
    time_sleep.wait_service_identity_propagation
  ]
}

module "cloud_function_core" {
  source = "../secure-cloud-function-core"

  function_name               = var.function_name
  function_description        = var.function_description
  project_id                  = var.serverless_project_id
  project_number              = var.serverless_project_number
  labels                      = var.labels
  location                    = var.location
  runtime                     = var.runtime
  entry_point                 = var.entry_point
  repo_source                 = var.repo_source
  storage_source              = var.storage_source
  build_environment_variables = var.build_environment_variables
  event_trigger               = var.event_trigger
  force_destroy               = !var.prevent_destroy
  encryption_key              = module.cloud_function_security.key_self_link
  bucket_lifecycle_rules      = var.bucket_lifecycle_rules
  bucket_cors                 = var.bucket_cors
  network_id                  = var.network_id

  service_config = {
    max_instance_count             = var.max_scale_instances
    min_instance_count             = var.min_scale_instances
    available_memory               = var.available_memory_mb
    timeout_seconds                = var.timeout_seconds
    vpc_connector                  = module.cloud_serverless_network.connector_id
    service_account_email          = var.service_account_email
    ingress_settings               = var.ingress_settings
    all_traffic_on_latest_revision = var.all_traffic_on_latest_revision
    vpc_connector_egress_settings  = var.vpc_egress_value
    runtime_env_variables          = var.environment_variables

    runtime_secret_env_variables = var.secret_environment_variables
    secret_volumes               = var.secret_volumes
  }

  depends_on = [
    google_service_account_iam_member.identity_service_account_user
  ]
}
