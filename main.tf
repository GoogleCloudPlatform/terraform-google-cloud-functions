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

/******************************************
	ZIP Archive of the Cloud Function Code
 *****************************************/
/*data "archive_file" "source" {
  type        = "zip"
  output_path = var.storage_source.filename
  source_dir  = var.storage_source.source_path
}*/

/******************************************
	Upload ZIP Archive to GCS Bucket
 *****************************************/
/*resource "google_storage_bucket_object" "object" {
  name   = "${var.storage_source.filepath}/${var.storage_source.filename}"
  bucket = var.storage_source.bucketname
  source = data.archive_file.source.output_path
}*/

/******************************************
	Cloud Function Definition with
	Repo/Storage	Build Source and Event Trigger
 *****************************************/
resource "google_cloudfunctions2_function" "function" {
  name        = var.function_name
  location    = var.function_location
  description = var.description
  project     = var.project_id

  build_config {
    runtime               = var.runtime
    entry_point           = var.entrypoint # Set the entry point
    environment_variables = var.build_env_variables

    source {
      dynamic "storage_source" {
        for_each = var.repo_source == null ? [var.storage_source] : []
        content {
          bucket = storage_source.value.bucketname
          #object = "${storage_source.value.filepath}/${storage_source.value.filename}"
          object     = storage_source.value.object
          generation = storage_source.value.generation
        }
      }

      /*storage_source {
        bucket = var.storage_source.bucketname
        object = "${var.storage_source.filepath}/${var.storage_source.filename}"
      }*/

      ### TODO: Repo Source has issues with building the function source.
      ##
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

      /*repo_source {
        project_id  = var.repo_source["project_id"]
        repo_name   = var.repo_source["repo_name"]
        commit_sha = var.repo_source["branch_name"]
        dir         = var.repo_source["dir"]
        #tag_name = ""
        #commit_sha= ""
        #invert_regex = ""
      }*/
    }

    worker_pool       = var.worker_pool
    docker_repository = var.docker_repository
  }

  dynamic "event_trigger" {
    for_each = var.event_trigger != null ? [var.event_trigger] : []
    content {
      trigger_region        = event_trigger.value["trigger_region"] != null ? event_trigger.value["trigger_region"] : null # same as the function
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

      /*event_filters {
        attribute = ""
        value = ""
        operator = ""
      }*/
    }
  }

  dynamic "service_config" {
    for_each = var.service_config != null ? [var.service_config] : []
    content {
      max_instance_count    = service_config.value.max_instance_count
      min_instance_count    = service_config.value.min_instance_count
      available_memory      = service_config.value.available_memory
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

      /*secret_environment_variables {
        key = ""
        project_id = ""
        secret = ""
        version = ""
      }*/

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

      /*secret_volumes {
        mount_path = ""
        project_id = ""
        secret = ""
        versions = {
          version = ""
          path = ""
        }
      }*/
    }
  }

  labels = var.labels != null ? var.labels : {}

  ### TODO: Cloud Function via Storage Source updates the function each time
  # Find a solution to avoid this update each time when there are no changes
  /*lifecycle {
    ignore_changes = [
      build_config,
      event_trigger,
    ]
  }*/
}
