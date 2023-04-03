# Secure Cloud Run Core

This module handles the basic deployment core configurations for Cloud Run module.

The resources/services/activations/deletions that this module will create/trigger are:

* Creates a Cloud Run Service.
* Adds "Secret Manager Secret Accessor" role on the Secret for the Service Account used to run Cloud Run.
* Creates a Load Balancer Service using Google-managed SSL certificates.
* Creates Cloud Armor Service only including the pre-configured rules for SQLi, XSS, LFI, RCE, RFI, Scanner Detection, Protocol Attack and Session Fixation.

## Usage

```hcl
module "cloud_run_core" {
  source = "GoogleCloudPlatform/cloud-run/google//modules/secure-cloud-run-core"
  version = "~> 0.3.0"

  service_name          = <SERVICE NAME>
  location              = <SERVICE LOCATION>
  region                = <REGION>
  domain                = <YOUR-DOMAIN>
  serverless_project_id = <SERVICE PROJECT ID>
  image                 = <IMAGE URL>
  cloud_run_sa          = <CLOUD RUN SERVICE ACCOUNT EMAIL>
  vpc_connector_id      = <VPC CONNECTOR ID>
  encryption_key        = <KMS KEY>
  env_vars              = <ENV VARIABLES>
  members               = <MEMBERS ALLOWED TO CALL SERVICE>
}

```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| build\_environment\_variables | A set of key/value environment variable pairs to be used when building the Function. | `map(string)` | `{}` | no |
| encryption\_key | The KMS Key to Encrypt Event Arc, source Bucket, docker repository. | `string` | n/a | yes |
| entry\_point | The name of a method in the function source which will be invoked when the function is executed. | `string` | n/a | yes |
| event\_trigger | A source that fires events in response to a condition in another service. | <pre>object({<br>    trigger_region        = optional(string)<br>    event_type            = string<br>    service_account_email = string<br>    pubsub_topic          = optional(string)<br>    retry_policy          = string<br>    event_filters = optional(set(object({<br>      attribute       = string<br>      attribute_value = string<br>      operator        = optional(string)<br>    })))<br>  })</pre> | n/a | yes |
| force\_destroy | Set the `force_destroy` attribute on the Cloud Storage. | `bool` | `false` | no |
| function\_description | The description of the Cloud Function to create. | `string` | `""` | no |
| function\_name | The name of the Cloud Function to create. | `string` | n/a | yes |
| labels | Labels to be assigned to resources. | `map(any)` | `{}` | no |
| location | Cloud Function deployment location. | `string` | n/a | yes |
| project\_id | The project ID to deploy to. | `string` | n/a | yes |
| project\_number | The project number to deploy to. | `string` | n/a | yes |
| repo\_source | The source repository where the Cloud Function Source is stored. Do not use combined with source\_path. | <pre>object({<br>    project_id   = optional(string)<br>    repo_name    = string<br>    branch_name  = string<br>    dir          = optional(string)<br>    tag_name     = optional(string)<br>    commit_sha   = optional(string)<br>    invert_regex = optional(bool, false)<br>  })</pre> | `null` | no |
| runtime | The runtime in which the function will be executed. | `string` | n/a | yes |
| service\_config | Details of the service | <pre>object({<br>    max_instance_count    = optional(string, 100)<br>    min_instance_count    = optional(string, 1)<br>    available_memory      = optional(string, "256M")<br>    timeout_seconds       = optional(string, 60)<br>    runtime_env_variables = optional(map(string), null)<br>    runtime_secret_env_variables = optional(set(object({<br>      key_name   = string<br>      project_id = optional(string)<br>      secret     = string<br>      version    = string<br>    })), null)<br>    secret_volumes = optional(set(object({<br>      mount_path = string<br>      project_id = optional(string)<br>      secret     = string<br>      versions = set(object({<br>        version = string<br>        path    = string<br>      }))<br>    })), null)<br>    vpc_connector                  = string<br>    vpc_connector_egress_settings  = optional(string, "PRIVATE_RANGES_ONLY")<br>    ingress_settings               = optional(string, "ALLOW_INTERNAL_AND_GCLB")<br>    service_account_email          = string<br>    all_traffic_on_latest_revision = optional(bool, true)<br>  })</pre> | n/a | yes |
| storage\_source | Get the source from this location in Google Cloud Storage. | <pre>object({<br>    bucket     = string<br>    object     = string<br>    generation = optional(string, null)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| service\_name | Name of the created service. |
| service\_url | The URL on which the deployed service is available. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

### Software

The following dependencies must be available:

* [Terraform](https://www.terraform.io/downloads.html) >= 0.13.0
* [Terraform Provider for GCP](https://github.com/terraform-providers/terraform-provider-google) plugin < 5.0

### APIs

A project with the following APIs enabled must be used to host the
resources of this module:

* Serverless Project
  * Google Cloud Run Service: `run.googleapis.com`
  * Google Compute Service: `compute.googleapis.com`

### Service Account

A service account with the following roles must be used to provision
the resources of this module:

* Cloud Run Developer: `roles/run.developer`
* Compute Network User: `roles/compute.networkUser`
* Artifact Registry Reader: `roles/artifactregistry.reader`
