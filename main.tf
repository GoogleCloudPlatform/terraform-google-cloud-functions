/**
 * Copyright 2022 Google LLC
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
  # If var.location is set, use it. Otherwise, use var.function_location.
  # This makes the change backward-compatible.
  effective_location = coalesce(var.location, var.function_location)
}

/******************************************
	Cloud Function Definition with
	Repo/Storage Build Source and Event Trigger
 *****************************************/
resource "google_cloudfunctions2_function" "function" {
  name        = var.function_name
  location    = local.effective_location
  description = var.description
  project     = var.project_id

  build_config {
    runtime               = var.runtime
    entry_point           = var.entrypoint
    environment_variables = var.build_env_variables
    service_account       = var.build_service_account

    source {
      dynamic "storage_source" {
        for_each = var.repo_source == null ? [var.storage_source] : []
        content {
          bucket     = storage_source.value.bucket
          object     = storage_source.value.object
          generation = storage_source.value.generation
        }
      }

      dynamic "repo_source" {
        for_each = var.storage_source == null ? [var.repo_source] : []
        content {
          project_id   = repo_source.value.project_id
          repo_name    = repo_source.value.repo_name
          branch_name  = repo_source.value.branch_name
          dir          = repo_source.value.dir
          tag_name     = repo_source.value.tag_name
          commit_sha   = repo_source.value.commit_sha
          invert_regex = repo_source.value.invert_regex
        }
      }
    }

    worker_pool       = var.worker_pool
    docker_repository = var.docker_repository
  }

  dynamic "event_trigger" {
    for_each = var.event_trigger != null ? [var.event_trigger] : []
    content {
      trigger_region        = event_trigger.value["trigger_region"] != null ? event_trigger.value["trigger_region"] : null
      event_type            = event_trigger.value["event_type"] != null ? event_trigger.value["event_type"] : null
      pubsub_topic          = event_trigger.value["pubsub_topic"] != null ? event_trigger.value["pubsub_topic"] : null
      service_account_email = event_trigger.value["service_account_email"] != null ? event_trigger.value["service_account_email"] : null
      retry_policy          = event_trigger.value["retry_policy"] != null ? event_trigger.value["retry_policy"] : null

      dynamic "event_filters" {
        for_each = event_trigger.value.event_filters != null ? event_trigger.value.event_filters : []
        content {
          attribute = event_filters.value.attribute
          value     = event_filters.value.attribute_value
          operator  = event_filters.value.operator
        }
      }
    }
  }

  dynamic "service_config" {
    for_each = var.service_config != null ? [var.service_config] : []
    content {
      max_instance_count    = service_config.value.max_instance_count
      min_instance_count    = service_config.value.min_instance_count
      available_memory      = service_config.value.available_memory
      available_cpu         = service_config.value.available_cpu
      timeout_seconds       = service_config.value.timeout_seconds
      environment_variables = service_config.value.runtime_env_variables != null ? service_config.value.runtime_env_variables : {}

      vpc_connector                 = service_config.value.vpc_connector
      vpc_connector_egress_settings = service_config.value.vpc_connector != null ? service_config.value.vpc_connector_egress_settings : null
      ingress_settings              = service_config.value.ingress_settings

      service_account_email          = service_config.value.service_account_email
      all_traffic_on_latest_revision = service_config.value.all_traffic_on_latest_revision

      dynamic "secret_environment_variables" {
        for_each = service_config.value.runtime_secret_env_variables != null ? service_config.value.runtime_secret_env_variables : []
        iterator = sev
        content {
          key        = sev.value.key_name
          project_id = sev.value.project_id
          secret     = sev.value.secret
          version    = sev.value.version
        }
      }

      dynamic "secret_volumes" {
        for_each = service_config.value.secret_volumes != null ? service_config.value.secret_volumes : []
        content {
          mount_path = secret_volumes.value.mount_path
          project_id = secret_volumes.value.project_id
          secret     = secret_volumes.value.secret
          dynamic "versions" {
            for_each = secret_volumes.value.versions != null ? secret_volumes.value.versions : []
            content {
              version = versions.value.version
              path    = versions.value.path
            }
          }
        }
      }
    }
  }

  labels = var.labels != null ? var.labels : {}
}

// IAM for invoking HTTP functions (roles/run.invoker)
resource "google_cloudfunctions2_function_iam_member" "invokers" {
  for_each       = toset(contains(keys(var.members), "invokers") ? var.members["invokers"] : [])
  location       = google_cloudfunctions2_function.function.location
  project        = google_cloudfunctions2_function.function.project
  cloud_function = google_cloudfunctions2_function.function.name
  role           = "roles/cloudfunctions.invoker"
  member         = each.value

  depends_on = [
    google_cloudfunctions2_function.function
  ]
}

// Read and write access to all functions-related resources (roles/run.developer)
resource "google_cloudfunctions2_function_iam_member" "developers" {
  for_each       = toset(contains(keys(var.members), "developers") ? var.members["developers"] : [])
  location       = google_cloudfunctions2_function.function.location
  project        = google_cloudfunctions2_function.function.project
  cloud_function = google_cloudfunctions2_function.function.name
  role           = "roles/cloudfunctions.developer"
  member         = each.value

  depends_on = [
    google_cloudfunctions2_function.function
  ]
}

// IAM for invoking HTTP functions (roles/run.invoker)
resource "google_cloud_run_service_iam_member" "invokers" {
  for_each = toset(contains(keys(var.members), "invokers") ? var.members["invokers"] : [])
  location = google_cloudfunctions2_function.function.location
  project  = google_cloudfunctions2_function.function.project
  service  = google_cloudfunctions2_function.function.name
  role     = "roles/run.invoker"
  member   = each.value

  depends_on = [
    google_cloudfunctions2_function.function
  ]
}

// Read and write access to all functions-related resources (roles/run.developer)
resource "google_cloud_run_service_iam_member" "developers" {
  for_each = toset(contains(keys(var.members), "developers") ? var.members["developers"] : [])
  location = google_cloudfunctions2_function.function.location
  project  = google_cloudfunctions2_function.function.project
  service  = google_cloudfunctions2_function.function.name
  role     = "roles/run.developer"
  member   = each.value

  depends_on = [
    google_cloudfunctions2_function.function
  ]
}
