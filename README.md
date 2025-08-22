# Terraform Google Cloud Functions (Gen 2) module

The Terraform module handles the deployment of Cloud Functions (Gen 2) on GCP.

The resources/services/activations/deletions that this module will create/trigger are:

- Deploy Cloud Functions (2nd Gen) with provided source code and trigger
- Provide Cloud Functions Invoker or Developer roles to the users and service accounts

## Assumptions and Prerequisites

This module assumes that below mentioned prerequisites are in place before consuming the module.

* APIs are enabled
* Permissions are available.
* You have explicitly granted the necessary IAM roles for the underlying service account used by Cloud Build, `build_service_account`. If `build_service_account` is not specified, then the default compute service account is used, which has [no default IAM roles in new organizations]([url](https://cloud.google.com/resource-manager/docs/secure-by-default-organizations#organization_policies_enforced_on_organization_resources)). At a minimum, the following IAM roles are required for the build service account:
    * `roles/logging.logWriter`
    * `roles/storage.objectViewer`
    * `roles/artifactregistry.writer`


## Usage

Basic usage of this module is as follows:

```hcl
module "cloud_functions2" {
  source  = "GoogleCloudPlatform/cloud-functions/google"
  version = "~> 0.7"

  # Required variables
  function_name      = "<FUNCTION_NAME>"
  project_id         = "<PROJECT_ID>"
  function_location  = "<LOCATION>"
  runtime            = "<RUNTIME>"
  entrypoint         = "<ENTRYPOINT>"
  storage_source = {
    bucket      = "<BUCKET_NAME>"
    object      = "<ARCHIVE_PATH>"
    generation  = "<GCS_GENERATION>"
  }
}
```

Functional examples are included in the
[examples](./examples/) directory.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| build\_env\_variables | User-provided build-time environment variables | `map(string)` | `null` | no |
| build\_service\_account | Cloud Function Build Service Account Id. This is The fully-qualified name of the service account to be used for building the container. | `string` | `null` | no |
| description | Short description of the function | `string` | `null` | no |
| docker\_repository | User managed repository created in Artifact Registry optionally with a customer managed encryption key. | `string` | `null` | no |
| entrypoint | The name of the function (as defined in source code) that will be executed. Defaults to the resource name suffix, if not specified | `string` | n/a | yes |
| event\_trigger | Event triggers for the function | <pre>object({<br>    trigger_region        = optional(string)<br>    event_type            = string<br>    service_account_email = string<br>    pubsub_topic          = optional(string)<br>    retry_policy          = string<br>    event_filters = optional(set(object({<br>      attribute       = string<br>      attribute_value = string<br>      operator        = optional(string)<br>    })))<br>  })</pre> | `null` | no |
| function\_location | The location of this cloud function | `string` | n/a | yes |
| function\_name | A user-defined name of the function | `string` | n/a | yes |
| labels | A set of key/value label pairs associated with this Cloud Function | `map(string)` | `null` | no |
| members | Cloud Function Invoker and Developer roles for Users/SAs. Key names must be developers and/or invokers | `map(list(string))` | `{}` | no |
| project\_id | Project ID to create Cloud Function | `string` | n/a | yes |
| repo\_source | Get the source from this location in a Cloud Source Repository | <pre>object({<br>    project_id   = optional(string)<br>    repo_name    = string<br>    branch_name  = string<br>    dir          = optional(string)<br>    tag_name     = optional(string)<br>    commit_sha   = optional(string)<br>    invert_regex = optional(bool, false)<br>  })</pre> | `null` | no |
| runtime | The runtime in which to run the function. | `string` | n/a | yes |
| service\_config | Details of the service | <pre>object({<br>    max_instance_count    = optional(string, 100)<br>    min_instance_count    = optional(string, 1)<br>    available_memory      = optional(string, "256M")<br>    available_cpu         = optional(string, 1)<br>    timeout_seconds       = optional(string, 60)<br>    runtime_env_variables = optional(map(string), null)<br>    runtime_secret_env_variables = optional(set(object({<br>      key_name   = string<br>      project_id = optional(string)<br>      secret     = string<br>      version    = string<br>    })), null)<br>    secret_volumes = optional(set(object({<br>      mount_path = string<br>      project_id = optional(string)<br>      secret     = string<br>      versions = set(object({<br>        version = string<br>        path    = string<br>      }))<br>    })), null)<br>    vpc_connector                  = optional(string, null)<br>    vpc_connector_egress_settings  = optional(string, null)<br>    ingress_settings               = optional(string, null)<br>    service_account_email          = optional(string, null)<br>    all_traffic_on_latest_revision = optional(bool, true)<br>  })</pre> | `{}` | no |
| storage\_source | Get the source from this location in Google Cloud Storage | <pre>object({<br>    bucket     = string<br>    object     = string<br>    generation = optional(string, null)<br>  })</pre> | `null` | no |
| worker\_pool | Name of the Cloud Build Custom Worker Pool that should be used to build the function. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| function\_name | Name of the Cloud Function (Gen 2) |
| function\_uri | URI of the Cloud Function (Gen 2) |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

These sections describe requirements for using this module.

### Software

The following dependencies must be available:

- [Terraform][terraform] v1.3+
- [Terraform Provider for GCP][terraform-provider-gcp] plugin v3.0

### Service Account

A service account with the following roles must be used to provision
the resources of this module:

- Storage Admin: `roles/storage.admin`
- Cloud Functions Admin: `roles/cloudfunctions.admin`
- Cloud Run Admin: `roles/run.admin`
- Pub/Sub Admin: `roles/pubsub.admin`
- Artifact Registry Admin: `roles/artifactregistry.admin`
- Cloud Build Editor: `roles/cloudbuild.builds.editor`
- Secret Manager Admin: `roles/secretmanager.admin`

The [Project Factory module][project-factory-module] and the
[IAM module][iam-module] may be used in combination to provision a
service account with the necessary roles applied.

### APIs

A project with the following APIs enabled must be used to host the
resources of this module:

- Google Cloud Storage JSON API: `storage-api.googleapis.com`
- Cloud Functions API: `cloudfunctions.googleapis.com`
- Cloud Run Admin API: `run.googleapis.com`
- Cloud Build API: `cloudbuild.googleapis.com`
- Artifact Registry API: `artifactregistry.googleapis.com`
- Pub/Sub API: `pubsub.googleapis.com`
- Secret Manager API: `secretmanager.googleapis.com`
- EventArc API: `eventarc.googleapis.com`

The [Project Factory module][project-factory-module] can be used to
provision a project with the necessary APIs enabled.

## Contributing

Refer to the [contribution guidelines](./CONTRIBUTING.md) for
information on contributing to this module.

[iam-module]: https://registry.terraform.io/modules/terraform-google-modules/iam/google
[project-factory-module]: https://registry.terraform.io/modules/terraform-google-modules/project-factory/google
[terraform-provider-gcp]: https://www.terraform.io/docs/providers/google/index.html
[terraform]: https://www.terraform.io/downloads.html

## Security Disclosures

Please see our [security disclosure process](./SECURITY.md).
