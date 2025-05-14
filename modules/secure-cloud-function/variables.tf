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

variable "location" {
  description = "The location where resources are going to be deployed."
  type        = string
}

variable "serverless_project_id" {
  description = "The project to deploy the cloud function service."
  type        = string
}

variable "serverless_project_number" {
  description = "The project number to deploy to."
  type        = number
  default     = null
}

variable "vpc_project_id" {
  description = "The host project for the shared vpc."
  type        = string
}

variable "network_id" {
  description = "VPC network ID which is going to be used to connect the WorkerPool."
  type        = string
}

variable "key_name" {
  description = "The name of KMS Key to be created and used in Cloud Run."
  type        = string
  default     = "cloud-run-kms-key"
}

variable "kms_project_id" {
  description = "The project where KMS will be created."
  type        = string
}

variable "function_name" {
  description = "Cloud Function name."
  type        = string
}

variable "function_description" {
  description = "Cloud Function description."
  type        = string
}

variable "service_account_email" {
  description = "Service account to be used on Cloud Function."
  type        = string
}

variable "connector_name" {
  description = "The name for the connector to be created."
  type        = string
  default     = "serverless-vpc-connector"
}

variable "subnet_name" {
  description = "Subnet name to be re-used to create Serverless Connector."
  type        = string
  default     = null
}

variable "shared_vpc_name" {
  description = "Shared VPC name which is going to be re-used to create Serverless Connector."
  type        = string
}

variable "all_traffic_on_latest_revision" {
  type        = bool
  description = "Timeout for each request."
  default     = true
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "A set of key/value environment variable pairs to assign to the function."
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

variable "prevent_destroy" {
  description = "Set the `prevent_destroy` lifecycle attribute on the Cloud KMS key."
  type        = bool
  default     = true
}

variable "keyring_name" {
  description = "Keyring name."
  type        = string
  default     = "cloud-run-kms-keyring"
}

variable "key_rotation_period" {
  description = "Period of key rotation in seconds."
  type        = string
  default     = "2592000s"
}

variable "key_protection_level" {
  description = "The protection level to use when creating a version based on this template. Possible values: [\"SOFTWARE\", \"HSM\"]"
  type        = string
  default     = "HSM"
}

variable "ip_cidr_range" {
  description = "The range of internal addresses that are owned by the subnetwork and which is going to be used by VPC Connector. For example, 10.0.0.0/28 or 192.168.0.0/28. Ranges must be unique and non-overlapping within a network. Only IPv4 is supported."
  type        = string
}

variable "create_subnet" {
  description = "The subnet will be created with the subnet_name variable if true. When false, it will use the subnet_name for the subnet."
  type        = bool
  default     = true
}

variable "policy_for" {
  description = "Policy Root: set one of the following values to determine where the policy is applied. Possible values: [\"project\", \"folder\", \"organization\"]."
  type        = string
  default     = "project"
}

variable "folder_id" {
  description = "The folder ID to apply the policy to."
  type        = string
  default     = ""
}

variable "organization_id" {
  description = "The organization ID to apply the policy to."
  type        = string
  default     = ""
}

variable "runtime" {
  description = "The runtime in which the function will be executed."
  type        = string
}

variable "entry_point" {
  description = "The name of a method in the function source which will be invoked when the function is executed."
  type        = string
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

variable "storage_source" {
  description = "Get the source from this location in Google Cloud Storage."
  type = object({
    bucket     = string
    object     = string
    generation = optional(string, null)
  })
  default = null
}

variable "labels" {
  description = "Labels to be assigned to resources."
  type        = map(any)
  default     = {}
}

variable "resource_names_suffix" {
  description = "A suffix to concat in the end of the network resources names being created."
  type        = string
  default     = null
}

variable "max_scale_instances" {
  description = "Sets the maximum number of container instances needed to handle all incoming requests or events from each revison from Cloud Run. For more information, access this [documentation](https://cloud.google.com/run/docs/about-instance-autoscaling)."
  type        = number
  default     = 2
}

variable "min_scale_instances" {
  description = "Sets the minimum number of container instances needed to handle all incoming requests or events from each revison from Cloud Run. For more information, access this [documentation](https://cloud.google.com/run/docs/about-instance-autoscaling)."
  type        = number
  default     = 1
}

variable "available_memory_mb" {
  type        = string
  default     = "256Mi"
  description = "The amount of memory in megabytes allotted for the function to use."
}

variable "timeout_seconds" {
  type        = number
  description = "Timeout for each request."
  default     = 120
}

variable "vpc_egress_value" {
  description = "Sets VPC Egress firewall rule. Supported values are VPC_CONNECTOR_EGRESS_SETTINGS_UNSPECIFIED, PRIVATE_RANGES_ONLY, and ALL_TRAFFIC."
  type        = string
  default     = "ALL_TRAFFIC"
}

variable "ingress_settings" {
  type        = string
  default     = "ALLOW_INTERNAL_AND_GCLB"
  description = "The ingress settings for the function. Allowed values are ALLOW_ALL, ALLOW_INTERNAL_AND_GCLB and ALLOW_INTERNAL_ONLY. Changes to this field will recreate the cloud function."
}

variable "secret_environment_variables" {
  type = set(object({
    key_name   = string
    project_id = optional(string)
    secret     = string
    version    = string
  }))
  default     = null
  description = "A list of maps which contains key, project_id, secret_name (not the full secret id) and version to assign to the function as a set of secret environment variables."
}

variable "secret_volumes" {
  type = set(object({
    mount_path = string
    project_id = optional(string)
    secret     = string
    versions = set(object({
      version = string
      path    = string
    }))
  }))
  description = "[Beta] Environment variables (Secret Manager)."
  default     = null
}

variable "groups" {
  description = <<EOT
  Groups which will have roles assigned.
  The Serverless Administrators email group which the following roles will be added: Cloud Run Admin, Compute Network Viewer and Compute Network User.
  The Serverless Security Administrators email group which the following roles will be added: Cloud Run Viewer, Cloud KMS Viewer and Artifact Registry Reader.
  The Cloud Run Developer email group which the following roles will be added: Cloud Run Developer, Artifact Registry Writer and Cloud KMS CryptoKey Encrypter.
  The Cloud Run User email group which the following roles will be added: Cloud Run Invoker.
  EOT

  type = object({
    group_serverless_administrator          = optional(string, null)
    group_serverless_security_administrator = optional(string, null)
    group_cloud_run_developer               = optional(string, null)
    group_cloud_run_user                    = optional(string, null)
  })

  default = {}
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

variable "time_to_wait_service_identity_propagation" {
  type        = string
  description = "The time to wait for service identity propagation."
  default     = "180s"
}
