/**
 * Copyright 2021 Google LLC
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

variable "project_id" {
  description = "Project ID to create Cloud Function"
  type        = string
}

variable "function_name" {
  description = "A user-defined name of the function"
  type        = string
}

variable "function_location" {
  description = "The location of this cloud function"
  type        = string
}

variable "description" {
  description = "Short description of the function"
  type        = string
  default     = null
}

variable "labels" {
  description = "A set of key/value label pairs associated with this Cloud Function"
  type        = map(string)
  default     = null
}

variable "runtime" {
  description = "The runtime in which to run the function."
  type        = string
}

variable "entrypoint" {
  description = "The name of the function (as defined in source code) that will be executed. Defaults to the resource name suffix, if not specified"
  type        = string
}

variable "build_env_variables" {
  description = "User-provided build-time environment variables"
  type        = map(string)
  default     = null
}

variable "worker_pool" {
  description = "Name of the Cloud Build Custom Worker Pool that should be used to build the function."
  type        = string
  default     = null
}

variable "docker_repository" {
  description = "User managed repository created in Artifact Registry optionally with a customer managed encryption key."
  type        = string
  default     = null
}

variable "storage_source" {
  description = "Get the source from this location in Google Cloud Storage"
  type = object({
    bucketname = string
    object     = string
    generation = string
  })
  default = null
}

variable "repo_source" {
  description = "Get the source from this location in a Cloud Source Repository"
  type = object({
    project_id   = string
    repo_name    = string
    branch_name  = string
    dir          = string
    tag_name     = string
    commit_sha   = string
    invert_regex = bool
  })
  default = null
}

variable "event_trigger" {
  description = "Event triggers for the function"
  type = object({
    trigger_region        = string
    event_type            = string
    service_account_email = string
    pubsub_topic          = string
    retry_policy          = string
    event_filters = set(object({
      attribute       = string
      attribute_value = string
      operator        = string
    }))
  })
  default = null
}

variable "service_config" {
  description = "Details of the service"
  type = object({
    max_instance_count    = string
    min_instance_count    = string
    available_memory      = string
    timeout_seconds       = string
    runtime_env_variables = map(string)
    runtime_secret_env_variables = set(object({
      key_name   = string
      project_id = string
      secret     = string
      version    = string
    }))
    secret_volumes = set(object({
      mount_path = string
      project_id = string
      secret     = string
      versions = set(object({
        version = string
        path    = string
      }))
    }))
    vpc_connector                  = string
    vpc_connector_egress_settings  = string
    ingress_settings               = string
    service_account_email          = string
    all_traffic_on_latest_revision = bool
  })
  default = null
}
