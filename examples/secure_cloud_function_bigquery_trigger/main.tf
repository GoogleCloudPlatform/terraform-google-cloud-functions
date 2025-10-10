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
  table_name      = "tbl_test"
  kms_bigquery    = "key-secure-bigquery"
  subnet_ip       = "10.0.0.0/28"

  cloud_services_sa = "${module.secure_harness.serverless_project_numbers[module.secure_harness.serverless_project_ids[0]]}@cloudservices.gserviceaccount.com"
}

resource "random_id" "random_folder_suffix" {
  byte_length = 2
}

module "secure_harness" {
  source  = "GoogleCloudPlatform/cloud-run/google//modules/secure-serverless-harness"
  version = "~> 0.21.5"

  billing_account                             = var.billing_account
  security_project_name                       = "prj-scf-security"
  network_project_name                        = "prj-scf-restricted-shared"
  serverless_project_names                    = ["prj-scf-bq-trigger"]
  org_id                                      = var.org_id
  parent_folder_id                            = var.folder_id
  serverless_folder_suffix                    = random_id.random_folder_suffix.hex
  region                                      = local.region
  location                                    = local.location
  vpc_name                                    = "vpc-secure-cloud-function"
  subnet_ip                                   = local.subnet_ip
  private_service_connect_ip                  = "10.3.0.5"
  create_access_context_manager_access_policy = var.create_access_context_manager_access_policy
  access_context_manager_policy_id            = var.access_context_manager_policy_id
  access_level_members                        = distinct(concat(var.access_level_members, ["serviceAccount:${var.terraform_service_account}"]))
  key_name                                    = "key-secure-artifact-registry"
  keyring_name                                = "krg-secure-artifact-registry"
  prevent_destroy                             = false
  artifact_registry_repository_name           = local.repository_name
  egress_policies                             = var.egress_policies
  ingress_policies                            = var.ingress_policies
  base_serverless_api                         = "cloudfunctions.googleapis.com"
  use_shared_vpc                              = true
  time_to_wait_vpc_sc_propagation             = "300s"
  project_deletion_policy                     = "DELETE"
  folder_deletion_protection                  = false

  service_account_project_roles = {
    "prj-scf-bq-trigger" = ["roles/eventarc.eventReceiver", "roles/viewer", "roles/compute.networkViewer", "roles/run.invoker"]
  }

  network_project_extra_apis = ["compute.googleapis.com", "networksecurity.googleapis.com"]

  serverless_project_extra_apis = {
    "prj-scf-bq-trigger" = ["compute.googleapis.com", "networksecurity.googleapis.com", "cloudfunctions.googleapis.com", "cloudbuild.googleapis.com", "eventarc.googleapis.com", "eventarcpublishing.googleapis.com"]
  }
}

module "cloudfunction_source_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 10.0"

  project_id    = module.secure_harness.serverless_project_ids[0]
  name          = "bkt-${local.location}-${module.secure_harness.serverless_project_numbers[module.secure_harness.serverless_project_ids[0]]}-cfv2-zip-files"
  location      = local.location
  storage_class = "REGIONAL"
  force_destroy = true

  encryption = {
    default_kms_key_name = module.secure_harness.artifact_registry_key
  }

  depends_on = [
    module.secure_harness
  ]
}

resource "google_project_service" "network_project_apis" {
  for_each           = toset(["networkservices.googleapis.com", "certificatemanager.googleapis.com"])
  project            = module.secure_harness.network_project_id[0]
  service            = each.value
  disable_on_destroy = false

  depends_on = [module.secure_harness]
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
  bucket = module.cloudfunction_source_bucket.name

  depends_on = [
    data.archive_file.cf_bigquery_source
  ]
}

data "google_bigquery_default_service_account" "bq_sa" {
  project = module.secure_harness.serverless_project_ids[0]
}

module "bigquery_kms" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.0"

  project_id           = module.secure_harness.security_project_id
  location             = local.location
  keyring              = "krg-secure-bigquery"
  keys                 = [local.kms_bigquery]
  set_decrypters_for   = [local.kms_bigquery]
  set_encrypters_for   = [local.kms_bigquery]
  decrypters           = ["serviceAccount:${data.google_bigquery_default_service_account.bq_sa.email}"]
  encrypters           = ["serviceAccount:${data.google_bigquery_default_service_account.bq_sa.email}"]
  prevent_destroy      = false
  key_rotation_period  = "2592000s"
  key_protection_level = "HSM"

  depends_on = [
    module.secure_harness
  ]
}

module "bigquery" {
  source  = "terraform-google-modules/bigquery/google"
  version = "~> 10.0"

  dataset_id                  = "dst_secure_cloud_function"
  dataset_name                = "dst-secure-cloud-function"
  description                 = "Dataset to trigger a secure Cloud Function"
  project_id                  = module.secure_harness.serverless_project_ids[0]
  location                    = local.location
  default_table_expiration_ms = 3600000
  encryption_key              = module.bigquery_kms.keys[local.kms_bigquery]

  tables = [
    {
      table_id          = local.table_name,
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
        env      = "development"
        billable = "true"
      }
  }]

  depends_on = [
    module.secure_harness
  ]
}

resource "null_resource" "generate_certificate" {
  triggers = {
    project_id = module.secure_harness.network_project_id[0]
    region     = local.region
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOT
      ${path.module}/../../helpers/generate_swp_certificate.sh \
        ${module.secure_harness.network_project_id[0]} \
        ${local.region}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      gcloud certificate-manager certificates delete swp-certificate \
        --location=${self.triggers.region} --project=${self.triggers.project_id} \
        --quiet
    EOT
  }

  depends_on = [
    module.secure_harness,
    google_project_service.network_project_apis
  ]
}

resource "time_sleep" "wait_upload_certificate" {
  create_duration  = "1m"
  destroy_duration = "1m"

  depends_on = [
    null_resource.generate_certificate
  ]
}

module "secure_web_proxy" {
  source  = "GoogleCloudPlatform/cloud-functions/google//modules/secure-web-proxy"
  version = "~> 0.6"

  project_id          = module.secure_harness.network_project_id[0]
  region              = local.region
  network_id          = module.secure_harness.service_vpc[0].network.id
  subnetwork_id       = "projects/${module.secure_harness.network_project_id[0]}/regions/${local.region}/subnetworks/${module.secure_harness.service_subnet[0]}"
  subnetwork_ip_range = local.subnet_ip
  certificates        = ["projects/${module.secure_harness.network_project_id[0]}/locations/${local.region}/certificates/swp-certificate"]
  addresses           = ["10.0.0.10"]
  ports               = [443]
  proxy_ip_range      = "10.129.0.0/23"

  # This list of URL was obtained through Cloud Function imports
  # It will change depending on what imports your CF are using.
  url_lists = [
    "*google.com/go*",
    "*github.com/GoogleCloudPlatform*",
    "*github.com/cloudevents*",
    "*golang.org/x*",
    "*google.golang.org/*",
    "*github.com/golang/*",
    "*github.com/google/*",
    "*github.com/googleapis/*",
    "*github.com/json-iterator/go",
    "*github.com/modern-go/concurrent",
    "*github.com/modern-go/reflect2",
    "*go.opencensus.io",
    "*go.uber.org/atomic",
    "*go.uber.org/multierr",
    "*go.uber.org/zap"
  ]

  depends_on = [
    module.secure_harness,
    null_resource.generate_certificate,
    time_sleep.wait_upload_certificate
  ]
}

resource "google_project_iam_member" "network_service_agent_editor" {
  project = module.secure_harness.network_project_id[0]
  role    = "roles/editor"
  member  = "serviceAccount:${local.cloud_services_sa}"

  depends_on = [module.secure_harness]
}

module "secure_cloud_function" {
  source  = "GoogleCloudPlatform/cloud-functions/google//modules/secure-cloud-function"
  version = "~> 0.6"

  function_name             = "secure-cloud-function-bigquery"
  function_description      = "Logs when there is a new row in the BigQuery"
  location                  = local.location
  serverless_project_id     = module.secure_harness.serverless_project_ids[0]
  serverless_project_number = module.secure_harness.serverless_project_numbers[module.secure_harness.serverless_project_ids[0]]
  vpc_project_id            = module.secure_harness.network_project_id[0]
  kms_project_id            = module.secure_harness.security_project_id
  key_name                  = "key-secure-cloud-function"
  keyring_name              = "krg-secure-cloud-function"
  service_account_email     = module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]
  connector_name            = "con-secure-cloud-function"
  subnet_name               = module.secure_harness.service_subnet[0]
  create_subnet             = false
  shared_vpc_name           = module.secure_harness.service_vpc[0].network.name
  prevent_destroy           = false
  ip_cidr_range             = local.subnet_ip
  network_id                = module.secure_harness.service_vpc[0].network.id

  # IPs used on Secure Web Proxy
  build_environment_variables = {
    HTTP_PROXY  = "http://10.0.0.10:443"
    HTTPS_PROXY = "http://10.0.0.10:443" # Using http because is a self-signed certification (just for test porpuse)
  }

  labels = {
    env      = "development"
    billable = "true"
  }

  storage_source = {
    bucket = module.cloudfunction_source_bucket.name
    object = google_storage_bucket_object.cf_bigquery_source_zip.name
  }

  environment_variables = {
    PROJECT_ID = module.secure_harness.serverless_project_ids[0]
    NAME       = "cloud function v2"
  }

  event_trigger = {
    event_type            = "google.cloud.audit.log.v1.written"
    trigger_region        = local.region
    service_account_email = module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]
    retry_policy          = "RETRY_POLICY_RETRY"
    event_filters = [{
      attribute       = "serviceName"
      attribute_value = "bigquery.googleapis.com"
      },
      {
        attribute       = "methodName"
        attribute_value = "google.cloud.bigquery.v2.JobService.InsertJob"
      },
      {
        attribute       = "resourceName"
        attribute_value = module.bigquery.bigquery_tables[local.table_name]["id"]
        operator        = "match-path-pattern" # This allows path patterns to be used in the value field
    }]
  }
  runtime     = "go121"
  entry_point = "HelloCloudFunction"

  depends_on = [
    module.secure_harness,
    module.bigquery,
    google_storage_bucket_object.cf_bigquery_source_zip,
    module.secure_web_proxy,
    google_project_iam_member.network_service_agent_editor
  ]
}
