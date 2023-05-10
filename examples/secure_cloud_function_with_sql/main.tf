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
  location        = "us-west1"
  region          = "us-west1"
  region_sql      = "us-central1"
  zone_sql        = "us-central1-a"
  repository_name = "rep-secure-cloud-function"
  kms_bigquery    = "key-secure-bigquery"
}
resource "random_id" "random_folder_suffix" {
  byte_length = 2
}

module "secure_harness" {
  # source  = "GoogleCloudPlatform/cloud-run/google//modules/secure-serverless-harness"
  # version = "~> 0.7"
  source = "git::https://github.com/amandakarina/terraform-google-cloud-run//modules/secure-serverless-harness?ref=fix/adds-missing-api-on-network-project"
  # amandakarina:fix/adds-missing-api-on-network-project
  # source = "../../../terraform-google-cloud-run/modules/secure-serverless-harness"

  billing_account                             = var.billing_account
  security_project_name                       = "prj-security"
  network_project_name                        = "prj-restricted-shared-tst"
  serverless_project_names                    = ["prj-secure-cloud-function", "prj-secure-cloud-sql"]
  org_id                                      = var.org_id
  parent_folder_id                            = var.folder_id
  serverless_folder_suffix                    = random_id.random_folder_suffix.hex
  region                                      = local.region
  location                                    = local.location
  vpc_name                                    = "vpc-secure-cloud-function"
  subnet_ip                                   = "10.0.0.0/28"
  private_service_connect_ip                  = "10.3.0.5"
  create_access_context_manager_access_policy = var.create_access_context_manager_access_policy
  access_context_manager_policy_id            = var.access_context_manager_policy_id
  access_level_members                        = var.access_level_members
  key_name                                    = "key-secure-artifact-registry"
  keyring_name                                = "krg-secure-artifact-registry"
  prevent_destroy                             = false
  artifact_registry_repository_name           = local.repository_name
  egress_policies                             = var.egress_policies
  ingress_policies                            = var.ingress_policies
  serverless_type                             = "CLOUD_FUNCTION"
  use_shared_vpc                              = true

  service_account_project_roles = {
    "prj-secure-cloud-function" = ["roles/eventarc.eventReceiver", "roles/viewer", "roles/compute.networkViewer", "roles/run.invoker"]
    "prj-secure-cloud-sql"      = []
  }

}

module "cloud_sql_subnet" {
  source  = "terraform-google-modules/network/google//modules/subnets"
  version = "~> 7.0"

  project_id   = module.secure_harness.network_project_id[0]
  network_name = module.secure_harness.service_vpc[0].network.name

  subnets = [
    {
      subnet_name   = "sb-${local.region_sql}-cloud-sql"
      subnet_ip     = "10.0.1.0/24"
      subnet_region = local.region_sql
    }
  ]
}

module "cloud_sql_private_service_access" {
  source      = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
  version     = "~> 15.0"
  project_id  = module.secure_harness.network_project_id[0]
  vpc_network = module.secure_harness.service_vpc[0].network.name
}

module "safer_mysql_db" {
  source               = "GoogleCloudPlatform/sql-db/google//modules/safer_mysql"
  version              = "~> 15.0"
  name                 = "csql-test"
  random_instance_name = true
  project_id           = module.secure_harness.serverless_project_ids[1]

  deletion_protection = false

  database_version = "MYSQL_5_6"
  region           = local.region_sql
  zone             = local.zone_sql
  tier             = "db-n1-standard-1"

  // By default, all users will be permitted to connect only via the
  // Cloud SQL proxy.
  additional_users = [
    {
      name            = "app"
      password        = "PaSsWoRd"
      host            = "localhost"
      type            = "BUILT_IN"
      random_password = false
    }
  ]

  assign_public_ip   = "true"
  vpc_network        = module.secure_harness.service_vpc[0].network.id
  allocated_ip_range = module.cloud_sql_private_service_access.google_compute_global_address_name

  depends_on = [ module.cloud_sql_private_service_access ]
}

data "archive_file" "cf_bigquery_source" {
  type        = "zip"
  source_dir  = "${path.module}/functions/bq-to-cf/"
  output_path = "functions/cloudfunction-bq-source-${random_id.random_folder_suffix.hex}.zip"
}

resource "google_storage_bucket_object" "cf_bigquery_source_zip" {
  source       = data.archive_file.cf_bigquery_source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.cf_bigquery_source.output_md5}.zip"
  bucket = module.secure_harness.cloudfunction_source_bucket[module.secure_harness.serverless_project_ids[0]].name

  depends_on = [
    data.archive_file.cf_bigquery_source
  ]
}

data "google_bigquery_default_service_account" "bq_sa" {
  project = module.secure_harness.serverless_project_ids[0]
}


module "pubsub" {
  source  = "terraform-google-modules/pubsub/google"
  version = "~> 5.0"

  topic      = "function2-topic"
  project_id = module.secure_harness.serverless_project_ids[0]
}

module "secure_cloud_function" {
  source = "../../modules/secure-cloud-function"

  function_name         = "secure-cloud-function-bigquery"
  function_description  = "Logs when there is a new row in the BigQuery"
  location              = local.location
  region                = local.region
  serverless_project_id = module.secure_harness.serverless_project_ids[0]
  vpc_project_id        = module.secure_harness.network_project_id[0]
  kms_project_id        = module.secure_harness.security_project_id
  key_name              = "key-secure-cloud-function"
  keyring_name          = "krg-secure-cloud-function"
  service_account_email = module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]
  connector_name        = "con-secure-cloud-function"
  subnet_name           = module.secure_harness.service_subnet[0]
  create_subnet         = false
  shared_vpc_name       = module.secure_harness.service_vpc[0].network.name
  prevent_destroy       = false
  ip_cidr_range         = "10.0.0.0/28"
  storage_source = {
    bucket = module.secure_harness.cloudfunction_source_bucket[module.secure_harness.serverless_project_ids[0]].name
    object = google_storage_bucket_object.cf_bigquery_source_zip.name
  }

  environment_variables = {
    PROJECT_ID = module.secure_harness.serverless_project_ids[0]
    NAME       = "cloud function v2"
  }

  event_trigger = {
    trigger_region        = "us-central1"
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    service_account_email = null
    trigger_region        = local.region
    pubsub_topic          = module.pubsub.id
    retry_policy          = "RETRY_POLICY_RETRY"
    event_filters         = null
    service_account_email = module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]
  }
  runtime     = "go118"
  entry_point = "HelloCloudFunction"

  depends_on = [
    module.secure_harness,
    google_storage_bucket_object.cf_bigquery_source_zip
  ]
}
