# /**
#  * Copyright 2023 Google LLC
#  *
#  * Licensed under the Apache License, Version 2.0 (the "License");
#  * you may not use this file except in compliance with the License.
#  * You may obtain a copy of the License at
#  *
#  *      http://www.apache.org/licenses/LICENSE-2.0
#  *
#  * Unless required by applicable law or agreed to in writing, software
#  * distributed under the License is distributed on an "AS IS" BASIS,
#  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  * See the License for the specific language governing permissions and
#  * limitations under the License.
#  */

locals {
  location           = "us-west1"
  region             = "us-west1"
  zone               = "us-west1-b"
  repository_name    = "rep-secure-cloud-function"
  network_ip         = "10.0.0.3"
  webserver_instance = "webserver"
  subnet_ip          = "10.0.0.0/28"
}
resource "random_id" "random_folder_suffix" {
  byte_length = 2
}

module "secure_harness" {
  #source  = "GoogleCloudPlatform/cloud-run/google//modules/secure-serverless-harness"
  #version = "~> 0.8"
  source = "git::https://github.com/amandakarina/terraform-google-cloud-run//modules/secure-serverless-harness?ref=feat/adds-harness-variable-to-customize-propagation-time"

  billing_account                             = var.billing_account
  security_project_name                       = "prj-security"
  network_project_name                        = "prj-restricted-shared"
  serverless_project_names                    = ["prj-secure-cloud-function"]
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
  serverless_type                             = "CLOUD_FUNCTION"
  use_shared_vpc                              = true
  time_to_wait_vpc_sc_propagation             = "360s"

  service_account_project_roles = {
    "prj-secure-cloud-function" = [
      "roles/eventarc.eventReceiver",
      "roles/viewer",
      "roles/compute.networkViewer",
      "roles/run.invoker"
    ]
  }

  network_project_extra_apis = [
    "certificatemanager.googleapis.com",
    "networkservices.googleapis.com",
    "networksecurity.googleapis.com"
  ]

  serverless_project_extra_apis = {
    "prj-secure-cloud-function" = [
      "networksecurity.googleapis.com"
    ]
  }
}

data "archive_file" "cf-internal-server-source" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "function/cloudfunction-${random_id.random_folder_suffix.hex}.zip"
}

resource "google_storage_bucket_object" "function-source" {
  source       = data.archive_file.cf-internal-server-source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.cf-internal-server-source.output_md5}.zip"
  bucket = module.secure_harness.cloudfunction_source_bucket[module.secure_harness.serverless_project_ids[0]].name

  depends_on = [
    data.archive_file.cf-internal-server-source
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
}

resource "time_sleep" "wait_upload_certificate" {
  create_duration  = "1m"
  destroy_duration = "1m"

  depends_on = [
    null_resource.generate_certificate
  ]
}

module "secure_web_proxy" {
  source = "git::https://github.com/Samir-Cit/terraform-google-cloud-functions.git//modules/secure-web-proxy?ref=fix/secure-web-proxy-fix"
  # source = "../../modules/secure-web-proxy"

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
    "*dl.google.com/*"
  ]

  depends_on = [
    module.secure_harness,
    null_resource.generate_certificate,
    time_sleep.wait_upload_certificate
  ]
}

module "secure_cloud_function" {
  source = "../../modules/secure-cloud-function"

  function_name             = "secure-function2-internal-server4"
  function_description      = "Secure cloud function example"
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
  ip_cidr_range             = "10.0.0.0/28"
  network_id                = module.secure_harness.service_vpc[0].network.id

  build_environment_variables = {
    HTTP_PROXY  = "http://10.0.0.10:443"
    HTTPS_PROXY = "http://10.0.0.10:443" # Using http because is a self-signed certification (just for test porpuse)
  }

  storage_source = {
    bucket = module.secure_harness.cloudfunction_source_bucket[module.secure_harness.serverless_project_ids[0]].name
    object = google_storage_bucket_object.function-source.name
  }

  environment_variables = {
    PROJECT_ID = module.secure_harness.serverless_project_ids[0]
    NAME       = "cloud function v2"
    TARGET_IP  = local.network_ip
  }

  event_trigger = {
    event_type            = "google.cloud.storage.object.v1.finalized"
    service_account_email = module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]
    retry_policy          = "RETRY_POLICY_RETRY"
    event_filters = [{
      attribute       = "bucket"
      attribute_value = module.secure_harness.cloudfunction_source_bucket[module.secure_harness.serverless_project_ids[0]].name
    }]
  }
  runtime     = "go118"
  entry_point = "helloHTTP"

  depends_on = [
    google_compute_instance.internal_server,
    google_storage_bucket_object.function-source,
    module.internal_server_firewall_rule,
    module.secure_web_proxy
  ]
}
