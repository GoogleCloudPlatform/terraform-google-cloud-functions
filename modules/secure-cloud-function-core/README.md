# Secure Cloud Function (2nd Gen) Core

This module handles the basic deployment core configurations for Cloud Function (2nd Gen) module.

The resources/services/activations/deletions that this module will create/trigger are:

* Creates a Cloud Function (2nd Gen).
* Creates the Cloud Function source bucket in the same location as the Cloud Function.
* Configure the EventArc Google Channel to use Customer Encryption Key in the Cloud Function location.
  * **Warning:** If there is another CMEK configured for the same region, it will be overwritten.
* Creates a private worker pool for Cloud Build configured to not use External IP.
* Grants Cloud Functions Invoker to EventArc Trigger Service Account.
* Enables Container Scanning.

## Usage

```hcl
module "secure_cloud_function_core" {
  source  = "GoogleCloudPlatform/cloud-functions/google//modules/secure-cloud-function-core"
  version = "~> 0.7"

  function_name               = <FUNCTION-NAME>
  function_description        = <FUNCTION-DESCRIPTION>
  project_id                  = <PROJECT-ID>
  project_number              = <PROJECT-NUMBER>
  labels                      = <RESOURCES-LABELS>
  location                    = <FUNCTION-LOCATION>
  runtime                     = <FUNCTION-RUNTIME>
  entry_point                 = <FUNCTION-ENTRY-POINT>
  storage_source              = <FUNCTION-SOURCE-BUCKET>
  build_environment_variables = <FUNCTION-BUILD-ENV-VARS>
  event_trigger               = <FUNCTION-EVENT-TRIGGER>
  encryption_key              = <CUSTOMER-ENCRYPTION-KEY>

  service_config = {
    vpc_connector                  = <FUNCTION-VPC-CONNECTOR>
    service_account_email          = <FUNCTION-SERVICE-ACCOUNT-EMAIL>
    ingress_settings               = "ALLOW_INTERNAL_AND_GCLB"
    all_traffic_on_latest_revision = true
    vpc_connector_egress_settings  = "ALL_TRAFFIC"
    runtime_env_variables          = <FUNCTION-RUNTIME-ENV-VARS>

    runtime_secret_env_variables = <FUNCTION-RUNTIME-SECRET-ENV-VARS>
    secret_volumes               = <FUNCTION-SECRET-VOLUMES>
}

```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket\_cors | Configuration of CORS for bucket with structure as defined in https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket#cors. | `any` | <pre>[<br>  {<br>    "max_age_seconds": 0,<br>    "method": [<br>      "GET"<br>    ],<br>    "origin": [<br>      "https://*.cloud.google.com",<br>      "https://*.corp.google.com",<br>      "https://*.corp.google.com:*",<br>      "https://*.cloud.google",<br>      "https://*.byoid.goog"<br>    ],<br>    "response_header": []<br>  }<br>]</pre> | no |
| bucket\_lifecycle\_rules | The bucket's Lifecycle Rules configuration. | <pre>list(object({<br>    # Object with keys:<br>    # - type - The type of the action of this Lifecycle Rule. Supported values: Delete and SetStorageClass.<br>    # - storage_class - (Required if action type is SetStorageClass) The target Storage Class of objects affected by this Lifecycle Rule.<br>    action = any<br><br>    # Object with keys:<br>    # - age - (Optional) Minimum age of an object in days to satisfy this condition.<br>    # - created_before - (Optional) Creation date of an object in RFC 3339 (e.g. 2017-06-13) to satisfy this condition.<br>    # - with_state - (Optional) Match to live and/or archived objects. Supported values include: "LIVE", "ARCHIVED", "ANY".<br>    # - matches_storage_class - (Optional) Storage Class of objects to satisfy this condition. Supported values include: MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, STANDARD, DURABLE_REDUCED_AVAILABILITY.<br>    # - matches_prefix - (Optional) One or more matching name prefixes to satisfy this condition.<br>    # - matches_suffix - (Optional) One or more matching name suffixes to satisfy this condition<br>    # - num_newer_versions - (Optional) Relevant only for versioned objects. The number of newer versions of an object to satisfy this condition.<br>    condition = any<br>  }))</pre> | <pre>[<br>  {<br>    "action": {<br>      "type": "Delete"<br>    },<br>    "condition": {<br>      "age": 0,<br>      "days_since_custom_time": 0,<br>      "days_since_noncurrent_time": 0,<br>      "num_newer_versions": 3,<br>      "with_state": "ARCHIVED"<br>    }<br>  }<br>]</pre> | no |
| build\_environment\_variables | A set of key/value environment variable pairs to be used when building the Function. | `map(string)` | `{}` | no |
| encryption\_key | The KMS Key to Encrypt Event Arc, source Bucket, docker repository. | `string` | n/a | yes |
| entry\_point | The name of a method in the function source which will be invoked when the function is executed. | `string` | n/a | yes |
| event\_trigger | A source that fires events in response to a condition in another service. | <pre>object({<br>    trigger_region        = optional(string)<br>    event_type            = string<br>    service_account_email = string<br>    pubsub_topic          = optional(string)<br>    retry_policy          = string<br>    event_filters = optional(set(object({<br>      attribute       = string<br>      attribute_value = string<br>      operator        = optional(string)<br>    })))<br>  })</pre> | n/a | yes |
| force\_destroy | Set the `force_destroy` attribute on the Cloud Storage. | `bool` | `false` | no |
| function\_description | The description of the Cloud Function to create. | `string` | `""` | no |
| function\_name | The name of the Cloud Function to create. | `string` | n/a | yes |
| labels | Labels to be assigned to resources. | `map(any)` | `{}` | no |
| location | Cloud Function deployment location. | `string` | `"us-east4"` | no |
| network\_id | VPC network ID which is going to be used to connect the WorkerPool. | `string` | n/a | yes |
| project\_id | The project ID to deploy to. | `string` | n/a | yes |
| project\_number | The project number to deploy to. | `number` | `null` | no |
| repo\_source | The source repository where the Cloud Function Source is stored. Do not use combined with source\_path. | <pre>object({<br>    project_id   = optional(string)<br>    repo_name    = string<br>    branch_name  = string<br>    dir          = optional(string)<br>    tag_name     = optional(string)<br>    commit_sha   = optional(string)<br>    invert_regex = optional(bool, false)<br>  })</pre> | `null` | no |
| runtime | The runtime in which the function will be executed. | `string` | n/a | yes |
| service\_config | Details of the service | <pre>object({<br>    max_instance_count    = optional(string, 100)<br>    min_instance_count    = optional(string, 1)<br>    available_memory      = optional(string, "256M")<br>    timeout_seconds       = optional(string, 60)<br>    runtime_env_variables = optional(map(string), null)<br>    runtime_secret_env_variables = optional(set(object({<br>      key_name   = string<br>      project_id = optional(string)<br>      secret     = string<br>      version    = string<br>    })), null)<br>    secret_volumes = optional(set(object({<br>      mount_path = string<br>      project_id = optional(string)<br>      secret     = string<br>      versions = set(object({<br>        version = string<br>        path    = string<br>      }))<br>    })), null)<br>    vpc_connector                  = string<br>    vpc_connector_egress_settings  = optional(string, "ALL_TRAFFIC")<br>    ingress_settings               = optional(string, "ALLOW_INTERNAL_AND_GCLB")<br>    service_account_email          = string<br>    all_traffic_on_latest_revision = optional(bool, true)<br>  })</pre> | n/a | yes |
| storage\_source | Get the source from this location in Google Cloud Storage. | <pre>object({<br>    bucket     = string<br>    object     = string<br>    generation = optional(string, null)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| artifact\_registry\_repository\_id | The ID of the Artifact Registry created to store Cloud Function images. |
| cloudbuild\_worker\_pool\_id | The ID of the Cloud Build worker pool created to build Cloud Function images. |
| cloudfunction\_bucket | The Cloud Function source bucket. |
| cloudfunction\_bucket\_name | Name of the Cloud Function source bucket. |
| cloudfunction\_name | Name of the created service. |
| cloudfunction\_url | The URL on which the deployed service is available. |
| eventarc\_google\_channel\_id | The ID of the Google Eventarc Channel. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

### Software

The following dependencies must be available:

* [Terraform](https://www.terraform.io/downloads.html) >= 1.3
* [Terraform Provider for GCP](https://github.com/terraform-providers/terraform-provider-google) plugin < 5.0

### APIs

A project with the following APIs enabled must be used to host the
resources of this module:

* Serverless Project
  * Container Scanning: `containerscanning.googleapis.com`

### Service Account

A service account with the following roles must be used to provision
the resources of this module:

* Viewer: `roles/viewer`
* Cloud Function Developer: `roles/cloudfunctions.developer`
* Compute Network User: `roles/compute.networkUser`
* Artifact Registry Admin: `roles/artifactregistry.admin`
* Cloud Build Editor: `roles/cloudbuild.builds.editor`
* Cloud Build Worker Pool Owner: `roles/cloudbuild.workerPoolOwner`
* Pub/Sub Admin: `roles/pubsub.admin`
* Storage Admin: `roles/storage.admin`
* Service Usage Admin: `roles/serviceusage.serviceUsageAdmin`
* Eventarc Developer: `roles/eventarc.developer`
