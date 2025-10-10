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
  location        = "us-central1"
  region          = "us-central1"
  zone_sql        = "us-central1-a"
  repository_name = "rep-secure-cloud-function"
  db_name         = "db-application"
  db_user         = "app"
  db_host         = "cloudsqlproxy~%"
  secret_name     = "sct-sql-password"
  labels          = { "env" = "dev" }
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
  serverless_project_names                    = ["prj-scf-access-sql", "prj-scf-cloud-sql"]
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

  network_project_extra_apis = ["compute.googleapis.com", "networksecurity.googleapis.com"]

  security_project_extra_apis = ["compute.googleapis.com", "secretmanager.googleapis.com"]

  serverless_project_extra_apis = {
    "prj-scf-access-sql" = ["compute.googleapis.com", "servicenetworking.googleapis.com", "sqladmin.googleapis.com", "cloudscheduler.googleapis.com", "networksecurity.googleapis.com", "cloudfunctions.googleapis.com", "cloudbuild.googleapis.com", "eventarc.googleapis.com", "eventarcpublishing.googleapis.com"],
    "prj-scf-cloud-sql"  = ["compute.googleapis.com", "sqladmin.googleapis.com", "sql-component.googleapis.com", "servicenetworking.googleapis.com"]
  }

  service_account_project_roles = {
    "prj-scf-access-sql" = ["roles/eventarc.eventReceiver", "roles/viewer", "roles/compute.networkViewer", "roles/run.invoker"]
    "prj-scf-cloud-sql"  = []
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

module "cloud_sql_temp_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 10.0"

  project_id    = module.secure_harness.serverless_project_ids[1]
  name          = "bkt-${local.location}-${module.secure_harness.serverless_project_numbers[module.secure_harness.serverless_project_ids[1]]}-temp-files"
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

resource "google_project_service_identity" "pubsub_sa" {
  provider = google-beta

  project    = module.secure_harness.serverless_project_ids[0]
  service    = "pubsub.googleapis.com"
  depends_on = [module.secure_harness]
}

resource "google_project_service_identity" "cloudsql_sa" {
  provider = google-beta

  project    = module.secure_harness.serverless_project_ids[1]
  service    = "sqladmin.googleapis.com"
  depends_on = [module.secure_harness]
}

resource "google_project_service_identity" "secrets_sa" {
  provider = google-beta

  project    = module.secure_harness.security_project_id
  service    = "secretmanager.googleapis.com"
  depends_on = [module.secure_harness]
}

resource "time_sleep" "wait_service_identity_propagation" {
  create_duration = var.time_to_wait_service_identity_propagation

  depends_on = [
    google_project_service_identity.pubsub_sa,
    google_project_service_identity.cloudsql_sa,
    google_project_service_identity.secrets_sa
  ]
}

module "kms_keys" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.0"

  project_id         = module.secure_harness.security_project_id
  location           = local.location
  keyring            = "krg-topic"
  keys               = ["key-topic", "key-sql", "key-secret"]
  set_decrypters_for = ["key-topic", "key-sql", "key-secret"]
  set_encrypters_for = ["key-topic", "key-sql", "key-secret"]
  decrypters = [
    "serviceAccount:${google_project_service_identity.pubsub_sa.email}",
    "serviceAccount:${google_project_service_identity.cloudsql_sa.email}",
    "serviceAccount:${google_project_service_identity.secrets_sa.email}"
  ]
  encrypters = [
    "serviceAccount:${google_project_service_identity.pubsub_sa.email}",
    "serviceAccount:${google_project_service_identity.cloudsql_sa.email}",
    "serviceAccount:${google_project_service_identity.secrets_sa.email}"
  ]
  prevent_destroy      = false
  key_rotation_period  = "2592000s"
  key_protection_level = "HSM"

  depends_on = [
    module.secure_harness,
    time_sleep.wait_service_identity_propagation
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
  destroy_duration = "3m"

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
    "*go.uber.org/zap",
    "*googlesource.com"
  ]

  depends_on = [
    module.secure_harness,
    null_resource.generate_certificate,
    time_sleep.wait_upload_certificate
  ]
}

module "safer_mysql_db" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/mysql"
  version = "~> 25.0"

  name                 = "csql-test"
  db_name              = local.db_name
  random_instance_name = true
  project_id           = module.secure_harness.serverless_project_ids[1]
  encryption_key_name  = module.kms_keys.keys["key-sql"]
  enable_default_user  = false
  deletion_protection  = false
  database_version     = "MYSQL_8_0"
  region               = local.region
  zone                 = local.zone_sql
  tier                 = "db-n1-standard-1"

  ip_configuration = {
    ipv4_enabled = false
    # We never set authorized networks, we need all connections via the
    # public IP to be mediated by Cloud SQL.
    authorized_networks = []
    require_ssl         = true
    private_network     = module.secure_harness.service_vpc[0].network.id
    allocated_ip_range  = module.secure_web_proxy.global_address_name
  }

  depends_on = [module.secure_web_proxy]
}

module "cloud_sql_firewall_rule" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 11.0"

  project_id   = module.secure_harness.network_project_id[0]
  network_name = module.secure_harness.service_vpc[0].network.name

  rules = [{
    name        = "fw-allow-tcp-3307-egress-to-sql-private-ip"
    description = "Allow Cloud Function to connect in Cloud SQL using the private IP"
    direction   = "EGRESS"
    priority    = 100
    ranges      = [module.safer_mysql_db.private_ip_address]
    source_tags = []
    allow = [{
      protocol = "tcp"
      ports    = ["3307"]
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}

resource "null_resource" "create_user_pwd" {

  triggers = {
    instance_name             = module.safer_mysql_db.instance_name,
    instance_project_id       = module.secure_harness.serverless_project_ids[1]
    secret_name               = google_secret_manager_secret.password_secret.id
    security_project_id       = module.secure_harness.security_project_id
    db_user                   = local.db_user
    db_host                   = local.db_host
    terraform_service_account = var.terraform_service_account
  }

  provisioner "local-exec" {
    command = <<EOF
    cd ${path.module}/helpers && chmod u+x create_db_user.sh && ./create_db_user.sh \
      ${var.terraform_service_account} \
      ${module.safer_mysql_db.instance_name} \
      ${module.secure_harness.serverless_project_ids[1]} \
      ${google_secret_manager_secret.password_secret.id} \
      ${module.secure_harness.security_project_id} \
      ${local.db_user} \
      ${local.db_host}
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
    cd ${path.module}/helpers && chmod u+x destroy_db_user.sh && ./destroy_db_user.sh \
      ${self.triggers.terraform_service_account} \
      ${self.triggers.instance_name} \
      ${self.triggers.instance_project_id} \
      ${self.triggers.db_user} \
      ${self.triggers.db_host}
    EOF
  }

  depends_on = [
    module.safer_mysql_db,
    google_secret_manager_secret.password_secret
  ]
}

resource "google_storage_bucket_iam_member" "object_admin" {
  bucket = module.cloud_sql_temp_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.safer_mysql_db.instance_service_account_email_address}"
}

resource "google_storage_bucket_object" "cloud_sql_dump_file" {
  source       = "${path.module}/assets/sample-db-data.sql"
  content_type = "text/plain; charset=utf-8"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "assets/sample-db-data.sql"
  bucket = module.cloud_sql_temp_bucket.name

  depends_on = [
    module.secure_harness
  ]
}

resource "null_resource" "create_and_populate_db" {

  triggers = {
    instance  = module.safer_mysql_db.instance_name,
    file_name = "${module.cloud_sql_temp_bucket.name}/${google_storage_bucket_object.cloud_sql_dump_file.name}"
  }

  provisioner "local-exec" {
    command = <<EOT
    gcloud sql import sql ${module.safer_mysql_db.instance_name} \
    --project ${module.secure_harness.serverless_project_ids[1]} \
    gs://${module.cloud_sql_temp_bucket.name}/${google_storage_bucket_object.cloud_sql_dump_file.name} \
    --database=${local.db_name} --impersonate-service-account=${var.terraform_service_account} -q
    EOT
  }

  depends_on = [
    google_storage_bucket_object.cloud_sql_dump_file,
    module.safer_mysql_db,
    google_storage_bucket_iam_member.object_admin,
    null_resource.create_user_pwd
  ]
}

data "archive_file" "cf_cloudsql_source" {
  type        = "zip"
  source_dir  = "${path.module}/functions/cf-to-sql/"
  output_path = "functions/cloudfunction-sql-source-${random_id.random_folder_suffix.hex}.zip"
}

resource "google_storage_bucket_object" "cf_cloudsql_source_zip" {
  source       = data.archive_file.cf_cloudsql_source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.cf_cloudsql_source.output_md5}.zip"
  bucket = module.cloudfunction_source_bucket.name

  depends_on = [
    data.archive_file.cf_cloudsql_source,
    module.secure_harness
  ]
}

resource "google_project_iam_member" "cloud_sql_roles" {
  for_each = toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])

  project    = module.secure_harness.serverless_project_ids[1]
  role       = each.value
  member     = "serviceAccount:${module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]}"
  depends_on = [module.secure_harness]
}

resource "google_secret_manager_secret" "password_secret" {
  secret_id = local.secret_name
  labels    = local.labels
  project   = module.secure_harness.security_project_id

  replication {
    user_managed {
      replicas {
        location = local.location
        customer_managed_encryption {
          kms_key_name = module.kms_keys.keys["key-secret"]
        }
      }
    }
  }
  depends_on = [module.kms_keys]
}

resource "google_secret_manager_secret_iam_member" "member" {
  project   = google_secret_manager_secret.password_secret.project
  secret_id = google_secret_manager_secret.password_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]}"
}

resource "google_cloud_scheduler_job" "job" {
  project     = module.secure_harness.serverless_project_ids[0]
  region      = local.region
  name        = "csch-job"
  description = "Secure Cloud Function with Cloud SQL example"
  schedule    = "*/2 * * * *"

  pubsub_target {
    topic_name = module.pubsub.id
    data       = base64encode("{'cloud_function' : 'true'}")
  }
}

module "pubsub" {
  source  = "terraform-google-modules/pubsub/google"
  version = "~> 7.0"

  topic              = "tpc-cloud-function-sql"
  project_id         = module.secure_harness.serverless_project_ids[0]
  topic_kms_key_name = module.kms_keys.keys["key-topic"]
  topic_labels       = local.labels
  depends_on         = [module.secure_harness]
}

data "google_secret_manager_secret_version" "latest_version" {
  project    = module.secure_harness.security_project_id
  secret     = local.secret_name
  depends_on = [null_resource.create_user_pwd]
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

  function_name             = "secure-cloud-function-cloud-sql"
  function_description      = "Read from Cloud SQL"
  location                  = local.location
  serverless_project_id     = module.secure_harness.serverless_project_ids[0]
  serverless_project_number = module.secure_harness.serverless_project_numbers[module.secure_harness.serverless_project_ids[0]]
  vpc_project_id            = module.secure_harness.network_project_id[0]
  labels                    = local.labels
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

  storage_source = {
    bucket = module.cloudfunction_source_bucket.name
    object = google_storage_bucket_object.cf_cloudsql_source_zip.name
  }

  environment_variables = {
    INSTANCE_PROJECT_ID = module.secure_harness.serverless_project_ids[1]
    INSTANCE_USER       = local.db_user
    INSTANCE_LOCATION   = local.region
    INSTANCE_NAME       = module.safer_mysql_db.instance_name
    DATABASE_NAME       = local.db_name
  }

  secret_environment_variables = [{
    key_name   = "INSTANCE_PWD"
    project_id = module.secure_harness.security_project_id
    secret     = local.secret_name
    version    = data.google_secret_manager_secret_version.latest_version.version
  }]

  event_trigger = {
    trigger_region        = local.location
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = module.pubsub.id
    retry_policy          = "RETRY_POLICY_RETRY"
    event_filters         = null
    service_account_email = module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]
  }

  runtime     = "go121"
  entry_point = "HelloCloudFunction"

  depends_on = [
    module.secure_harness,
    google_storage_bucket_object.cf_cloudsql_source_zip,
    google_secret_manager_secret_iam_member.member,
    null_resource.create_and_populate_db,
    null_resource.create_user_pwd,
    module.secure_web_proxy,
    google_project_iam_member.network_service_agent_editor
  ]
}
