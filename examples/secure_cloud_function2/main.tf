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
  repository_name = "rep-secure-cloud-function"
}
resource "random_id" "random_folder_suffix" {
  byte_length = 2
}

module "secure_harness" {
  # source  = "GoogleCloudPlatform/cloud-run/google//modules/secure-serverless-harness"
  # version = "~> 0.7"
  #   source = "git::https://github.com/amandakarina/terraform-google-cloud-run.git//modules/secure-serverless-harness?ref=feat/adds-support-to-multiple-services-project-and-shared-vpc"
  source = "../../../terraform-google-cloud-run/modules/secure-serverless-harness"

  billing_account                             = var.billing_account
  security_project_name                       = "prj-security"
  network_project_name                        = "prj-restricted-shared-tst"
  serverless_project_names                    = ["prj-secure-cloud-function"]
  org_id                                      = var.org_id
  parent_folder_id                            = var.parent_folder_id
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
  }

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

module "bigquery" {
  source  = "terraform-google-modules/bigquery/google"
  version = "~> 5.4"

  dataset_id                  = "dst_secure_cloud_function"
  dataset_name                = "dst-secure-cloud-function"
  description                 = "Dataset to trigger a secure Cloud Function"
  project_id                  = module.secure_harness.serverless_project_ids[0]
  location                    = local.location
  default_table_expiration_ms = 3600000

  tables = [
    {
      table_id          = "tbl_test",
      schema            = file("${path.module}/templates/bigquery_schema.template")
      time_partitioning = null,
      range_partitioning = {
        field = "Card_PIN",
        range = {
          start    = "1"
          end      = "100",
          interval = "10",
        },
      },
      expiration_time = 2524604400000, # 2050/01/01
      clustering      = [],
      labels = {
        env      = "production"
        billable = "true"
      }
  }]
  depends_on = [
    module.secure_harness
  ]
}

module "secure_cloud_function" {
  # source = "../../modules/secure-cloud-function"
  source = "git::https://github.com/amandakarina/terraform-google-cloud-functions.git//modules/secure-cloud-function?ref=feat/adds-secure-cloud-function-module"

  function_name         = "secure-cloud-function-bigquery"
  function_description  = "Logs when there is a change in the BigQuery"
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
  ip_cidr_range         = "10.0.0.0/28"
  storage_source = {
    bucket = module.secure_harness.cloudfunction_source_bucket[module.secure_harness.serverless_project_ids[0]].name
    object = google_storage_bucket_object.cf_bigquery_source_zip.name
  }

  event_trigger = {
    event_type            = "google.cloud.bigquery.storage.v1.BigQueryWrite.AppendRows"
    service_account_email = module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]
    retry_policy          = "RETRY_POLICY_RETRY"
    event_filters = [{
      attribute       = "bigquery.googleapis.com"
      attribute_value = module.bigquery.table_names[0]
    }]
  }
  runtime     = "go118"
  entry_point = "HelloCloudFunction"

  depends_on = [
    module.secure_harness,
    module.bigquery,
    google_storage_bucket_object.cf_bigquery_source_zip
  ]
}
