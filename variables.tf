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
  description = "DEPRECATED: Please use the 'location' variable instead. This will be removed in a future version."
  type        = string
  default     = null
}

variable "location" {
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
    bucket     = string
    object     = string
    generation = optional(string, null)
  })
  default = null
}

variable "repo_source" {
  description = "Get the source from this location in a Cloud Source Repository"
  type = object({
    project_id   = optional(string)
    repo_name    = string
    branch_name  = string
    dir          = optional(string)
    tag_name     = optional(string)
    commit_sha   = optional(string)
    invert_regex = optional(bool, false)
  })
  default = null
}

variable "event_trigger" {
  description = "Event triggers for the function"
  type = object({
    trigger_region        = optional(string)
    event_type            = string
    service_account_email = string
    pubsub_topic          = optional(string)
    retry_policy          = string
    event_filters = optional(set(object({
      attribute       = string
      attribute_value = string
      operator        = optional(string)
    })))
  })
  default = null
}

variable "service_config" {
  description = "Details of the service"
  type = object({
    max_instance_count    = optional(string, 100)
    min_instance_count    = optional(string, 1)
    available_memory      = optional(string, "256M")
    available_cpu         = optional(string, 1)
    timeout_seconds       = optional(string, 60)
    runtime_env_variables = optional(map(string), null)
    runtime_secret_env_variables = optional(set(object({
      key_name   = string
      project_id = optional(string)
      secret     = string
      version    = string
    })), null)
    secret_volumes = optional(set(object({
      mount_path = string
      project_id = optional(string)
      secret     = string
      versions = set(object({
        version = string
        path    = string
      }))
    })), null)
    vpc_connector                  = optional(string, null)
    vpc_connector_egress_settings  = optional(string, null)
    ingress_settings               = optional(string, null)
    service_account_email          = optional(string, null)
    all_traffic_on_latest_revision = optional(bool, true)
  })
  default = {}
}

// IAM
variable "members" {
  type        = map(list(string))
  description = "Cloud Function Invoker and Developer roles for Users/SAs. Key names must be developers and/or invokers"
  default     = {}
  validation {
    condition = alltrue([
      for key in keys(var.members) : contains(["invokers", "developers"], key)
    ])
    error_message = "The supported keys are invokers and developers."
  }
}

variable "build_service_account" {
  type        = string
  description = "Cloud Function Build Service Account Id. This is The fully-qualified name of the service account to be used for building the container."
  default     = null
}
