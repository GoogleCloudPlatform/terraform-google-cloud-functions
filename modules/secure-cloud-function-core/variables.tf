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


variable "project_id" {
  description = "The project ID to deploy to."
  type        = string
}

variable "vpc_project_id" {
  description = "The host project for the shared vpc."
  type        = string
}

variable "shared_vpc_name" {
  description = "Shared VPC name which is going to be used to connect the WorkerPool."
  type        = string
}

variable "project_number" {
  description = "The project number to deploy to."
  type        = number
  default     = null
}

variable "encryption_key" {
  description = "The KMS Key to Encrypt Event Arc, source Bucket, docker repository."
  type        = string
}

variable "function_name" {
  description = "The name of the Cloud Function to create."
  type        = string
}

variable "function_description" {
  description = "The description of the Cloud Function to create."
  type        = string
  default     = ""
}

variable "labels" {
  description = "Labels to be assigned to resources."
  type        = map(any)
  default     = {}
}

variable "location" {
  description = "Cloud Function deployment location."
  type        = string
  default     = "us-east4"
}

variable "runtime" {
  description = "The runtime in which the function will be executed."
  type        = string
}

variable "entry_point" {
  description = "The name of a method in the function source which will be invoked when the function is executed."
  type        = string
}

variable "storage_source" {
  description = "Get the source from this location in Google Cloud Storage."
  type = object({
    bucket     = string
    object     = string
    generation = optional(string, null)
  })
  default = null
}

variable "repo_source" {
  description = "The source repository where the Cloud Function Source is stored. Do not use combined with source_path."
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

variable "build_environment_variables" {
  type        = map(string)
  default     = {}
  description = "A set of key/value environment variable pairs to be used when building the Function."
}

variable "event_trigger" {
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
  description = "A source that fires events in response to a condition in another service."
}

variable "service_config" {
  type = object({
    max_instance_count    = optional(string, 100)
    min_instance_count    = optional(string, 1)
    available_memory      = optional(string, "256M")
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
    vpc_connector                  = string
    vpc_connector_egress_settings  = optional(string, "PRIVATE_RANGES_ONLY")
    ingress_settings               = optional(string, "ALLOW_INTERNAL_AND_GCLB")
    service_account_email          = string
    all_traffic_on_latest_revision = optional(bool, true)
  })
  description = "Details of the service"
}

variable "force_destroy" {
  description = "Set the `force_destroy` attribute on the Cloud Storage."
  type        = bool
  default     = false
}

variable "bucket_cors" {
  description = "Configuration of CORS for bucket with structure as defined in https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket#cors."
  type        = any
  default = [{
    max_age_seconds = 0
    method = [
      "GET",
    ]
    origin = [
      "https://*.cloud.google.com",
      "https://*.corp.google.com",
      "https://*.corp.google.com:*",
      "https://*.cloud.google",
      "https://*.byoid.goog",
    ]
    response_header = []
  }]
}

variable "bucket_lifecycle_rules" {
  description = "The bucket's Lifecycle Rules configuration."
  type = list(object({
    # Object with keys:
    # - type - The type of the action of this Lifecycle Rule. Supported values: Delete and SetStorageClass.
    # - storage_class - (Required if action type is SetStorageClass) The target Storage Class of objects affected by this Lifecycle Rule.
    action = any

    # Object with keys:
    # - age - (Optional) Minimum age of an object in days to satisfy this condition.
    # - created_before - (Optional) Creation date of an object in RFC 3339 (e.g. 2017-06-13) to satisfy this condition.
    # - with_state - (Optional) Match to live and/or archived objects. Supported values include: "LIVE", "ARCHIVED", "ANY".
    # - matches_storage_class - (Optional) Storage Class of objects to satisfy this condition. Supported values include: MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, STANDARD, DURABLE_REDUCED_AVAILABILITY.
    # - matches_prefix - (Optional) One or more matching name prefixes to satisfy this condition.
    # - matches_suffix - (Optional) One or more matching name suffixes to satisfy this condition
    # - num_newer_versions - (Optional) Relevant only for versioned objects. The number of newer versions of an object to satisfy this condition.
    condition = any
  }))
  default = [{
    action = {
      type = "Delete"
    }
    condition = {
      age                        = 0
      days_since_custom_time     = 0
      days_since_noncurrent_time = 0
      num_newer_versions         = 3
      with_state                 = "ARCHIVED"
    }
  }]
}
