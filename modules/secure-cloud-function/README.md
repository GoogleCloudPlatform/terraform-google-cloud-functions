# Secure Cloud Function

This module handles the deployment required for Cloud Function (2nd Gen) usage. Secure-cloud-function module will call the secure-cloud-function-core, secure-cloud-serverless-net and secure-cloud-function-security modules.

When using a Shared VPC, you can chose where to create the VPC Connector.

_Note:_ When using a single VPC you should provides VPC and Serverless project id with the same value and the value for `connector_on_host_project` variable must be `false`.

The resources/services/activations/deletions that this module will create/trigger are:

* secure-cloud-serverless-network module will apply:
  * Creates Firewall rules on your **VPC Project**.
    * Serverless to VPC Connector
    * VPC Connector to Serverless
    * VPC Connector to LB
    * VPC Connector Health Checks
  * Creates a sub network to VPC Connector usage purpose.
  * Creates Serverless Connector on your **VPC Project** or **Serverless Project**. Refer the comparison below:
    * Advantages of creating connectors in the [VPC Project](https://cloud.google.com/run/docs/configuring/connecting-shared-vpc#host-project)
    * Advantages of creating connectors in the [Serverless Project](https://cloud.google.com/run/docs/configuring/connecting-shared-vpc#service-projects)
  * Grant the necessary roles for Cloud Function are able to use VPC Connector on your Shared VPC when creating VPC Connector in host project.
    * Grant Network User role to Cloud Services service account.
    * Grant VPC Access User to Cloud Function Service Identity when deploying VPC Access.

* secure-cloud-function-security module will apply:
  * Creates KMS Keyring and Key for [customer managed encryption keys](https://cloud.google.com/run/docs/securing/using-cmek) in the **KMS Project** to be used by Cloud Function (2nd Gen).
  * Enables Organization Policies related to Cloud Function (2nd Gen) in the **Serverless Project**.
    * Allow Ingress only from internal and Cloud Load Balancing.
    * Allow VPC Egress to Private Ranges Only.
  * When groups emails are provided, this module will grant the roles for each persona.
    * Serverless administrator - Service Project
      * roles/run.admin
      * roles/cloudfunctions.admin
      * roles/compute.networkViewer
      * compute.networkUser
    * Servervless Security Administrator - Security project
      * roles/cloudfunctions.viewer
      * roles/run.viewer
      * roles/cloudkms.viewer
      * roles/artifactregistry.reader
    * Cloud Function (2nd Gen) developer - Security project
      * roles/cloudfunctions.developer
      * roles/artifactregistry.writer
      * roles/cloudkms.cryptoKeyEncrypter
    * Cloud Function (2nd Gen) user - Service project
      * roles/cloudfunctions.invoker

* secure-cloud-function-core module will apply:
  * Creates a Cloud Function (2nd Gen).
  * Creates the Cloud Function source bucket in the same location as the Cloud Function.
  * Configure the EventArc Google Channel to use Customer Encryption Key in the Cloud Function location.
    * **Warning:** If there is another CMEK configured for the same region, it will be overwritten.
  * Creates a private worker pool for Cloud Build configured to not use External IP.
  * Grants Cloud Functions Invoker to EventArc Trigger Service Account.
  * Enables Container Scanning.

## Usage

Basic usage of this module is as follows:

```hcl
module "secure_cloud_function" {
  source  = "GoogleCloudPlatform/cloud-functions/google//modules/secure-cloud-function"
  version = "~> 0.7"

  function_name             = <FUNCTION-NAME>
  function_description      = <FUNCTION-DESCRIPTION>
  location                  = <FUNCTION-LOCATION>
  region                    = <FUNCTION-REGION>
  serverless_project_id     = <FUNCTION-PROJECT-ID>
  vpc_project_id            = <VPC-PROJECT-ID>
  kms_project_id            = <KMS-PROJECT-IF>
  key_name                  = <KMS-KEY-NAME>
  keyring_name              = <KMS-KEYRING-NAME>
  service_account_email     = <FUNCTION-SERVICE-ACCOUNT>
  connector_name            = <VPC-CONNECTOR-NAME>
  subnet_name               = <SUBNET-NAME>
  create_subnet             = false
  shared_vpc_name           = <SHARE-VPC-NAME>
  ip_cidr_range             = "10.0.0.0/28"

  storage_source = {
     bucket = <SOURCE-BUCKET-NAME>
     object = <SOURCE-FILE-NAME>
  }
  runtime     = <FUNCTION-RUNTIME>
  entry_point = <FUNCTION-ENTRY-POINT>
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| all\_traffic\_on\_latest\_revision | Timeout for each request. | `bool` | `true` | no |
| available\_memory\_mb | The amount of memory in megabytes allotted for the function to use. | `string` | `"256Mi"` | no |
| bucket\_cors | Configuration of CORS for bucket with structure as defined in https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket#cors. | `any` | <pre>[<br>  {<br>    "max_age_seconds": 0,<br>    "method": [<br>      "GET"<br>    ],<br>    "origin": [<br>      "https://*.cloud.google.com",<br>      "https://*.corp.google.com",<br>      "https://*.corp.google.com:*",<br>      "https://*.cloud.google",<br>      "https://*.byoid.goog"<br>    ],<br>    "response_header": []<br>  }<br>]</pre> | no |
| bucket\_lifecycle\_rules | The bucket's Lifecycle Rules configuration. | <pre>list(object({<br>    # Object with keys:<br>    # - type - The type of the action of this Lifecycle Rule. Supported values: Delete and SetStorageClass.<br>    # - storage_class - (Required if action type is SetStorageClass) The target Storage Class of objects affected by this Lifecycle Rule.<br>    action = any<br><br>    # Object with keys:<br>    # - age - (Optional) Minimum age of an object in days to satisfy this condition.<br>    # - created_before - (Optional) Creation date of an object in RFC 3339 (e.g. 2017-06-13) to satisfy this condition.<br>    # - with_state - (Optional) Match to live and/or archived objects. Supported values include: "LIVE", "ARCHIVED", "ANY".<br>    # - matches_storage_class - (Optional) Storage Class of objects to satisfy this condition. Supported values include: MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, STANDARD, DURABLE_REDUCED_AVAILABILITY.<br>    # - matches_prefix - (Optional) One or more matching name prefixes to satisfy this condition.<br>    # - matches_suffix - (Optional) One or more matching name suffixes to satisfy this condition<br>    # - num_newer_versions - (Optional) Relevant only for versioned objects. The number of newer versions of an object to satisfy this condition.<br>    condition = any<br>  }))</pre> | <pre>[<br>  {<br>    "action": {<br>      "type": "Delete"<br>    },<br>    "condition": {<br>      "age": 0,<br>      "days_since_custom_time": 0,<br>      "days_since_noncurrent_time": 0,<br>      "num_newer_versions": 3,<br>      "with_state": "ARCHIVED"<br>    }<br>  }<br>]</pre> | no |
| build\_environment\_variables | A set of key/value environment variable pairs to be used when building the Function. | `map(string)` | `{}` | no |
| connector\_name | The name for the connector to be created. | `string` | `"serverless-vpc-connector"` | no |
| create\_subnet | The subnet will be created with the subnet\_name variable if true. When false, it will use the subnet\_name for the subnet. | `bool` | `true` | no |
| entry\_point | The name of a method in the function source which will be invoked when the function is executed. | `string` | n/a | yes |
| environment\_variables | A set of key/value environment variable pairs to assign to the function. | `map(string)` | `{}` | no |
| event\_trigger | A source that fires events in response to a condition in another service. | <pre>object({<br>    trigger_region        = optional(string)<br>    event_type            = string<br>    service_account_email = string<br>    pubsub_topic          = optional(string)<br>    retry_policy          = string<br>    event_filters = optional(set(object({<br>      attribute       = string<br>      attribute_value = string<br>      operator        = optional(string)<br>    })))<br>  })</pre> | n/a | yes |
| folder\_id | The folder ID to apply the policy to. | `string` | `""` | no |
| function\_description | Cloud Function description. | `string` | n/a | yes |
| function\_name | Cloud Function name. | `string` | n/a | yes |
| groups | Groups which will have roles assigned.<br>  The Serverless Administrators email group which the following roles will be added: Cloud Run Admin, Compute Network Viewer and Compute Network User.<br>  The Serverless Security Administrators email group which the following roles will be added: Cloud Run Viewer, Cloud KMS Viewer and Artifact Registry Reader.<br>  The Cloud Run Developer email group which the following roles will be added: Cloud Run Developer, Artifact Registry Writer and Cloud KMS CryptoKey Encrypter.<br>  The Cloud Run User email group which the following roles will be added: Cloud Run Invoker. | <pre>object({<br>    group_serverless_administrator          = optional(string, null)<br>    group_serverless_security_administrator = optional(string, null)<br>    group_cloud_run_developer               = optional(string, null)<br>    group_cloud_run_user                    = optional(string, null)<br>  })</pre> | `{}` | no |
| ingress\_settings | The ingress settings for the function. Allowed values are ALLOW\_ALL, ALLOW\_INTERNAL\_AND\_GCLB and ALLOW\_INTERNAL\_ONLY. Changes to this field will recreate the cloud function. | `string` | `"ALLOW_INTERNAL_AND_GCLB"` | no |
| ip\_cidr\_range | The range of internal addresses that are owned by the subnetwork and which is going to be used by VPC Connector. For example, 10.0.0.0/28 or 192.168.0.0/28. Ranges must be unique and non-overlapping within a network. Only IPv4 is supported. | `string` | n/a | yes |
| key\_name | The name of KMS Key to be created and used in Cloud Run. | `string` | `"cloud-run-kms-key"` | no |
| key\_protection\_level | The protection level to use when creating a version based on this template. Possible values: ["SOFTWARE", "HSM"] | `string` | `"HSM"` | no |
| key\_rotation\_period | Period of key rotation in seconds. | `string` | `"2592000s"` | no |
| keyring\_name | Keyring name. | `string` | `"cloud-run-kms-keyring"` | no |
| kms\_project\_id | The project where KMS will be created. | `string` | n/a | yes |
| labels | Labels to be assigned to resources. | `map(any)` | `{}` | no |
| location | The location where resources are going to be deployed. | `string` | n/a | yes |
| max\_scale\_instances | Sets the maximum number of container instances needed to handle all incoming requests or events from each revison from Cloud Run. For more information, access this [documentation](https://cloud.google.com/run/docs/about-instance-autoscaling). | `number` | `2` | no |
| min\_scale\_instances | Sets the minimum number of container instances needed to handle all incoming requests or events from each revison from Cloud Run. For more information, access this [documentation](https://cloud.google.com/run/docs/about-instance-autoscaling). | `number` | `1` | no |
| network\_id | VPC network ID which is going to be used to connect the WorkerPool. | `string` | n/a | yes |
| organization\_id | The organization ID to apply the policy to. | `string` | `""` | no |
| policy\_for | Policy Root: set one of the following values to determine where the policy is applied. Possible values: ["project", "folder", "organization"]. | `string` | `"project"` | no |
| prevent\_destroy | Set the `prevent_destroy` lifecycle attribute on the Cloud KMS key. | `bool` | `true` | no |
| repo\_source | The source repository where the Cloud Function Source is stored. Do not use combined with source\_path. | <pre>object({<br>    project_id   = optional(string)<br>    repo_name    = string<br>    branch_name  = string<br>    dir          = optional(string)<br>    tag_name     = optional(string)<br>    commit_sha   = optional(string)<br>    invert_regex = optional(bool, false)<br>  })</pre> | `null` | no |
| resource\_names\_suffix | A suffix to concat in the end of the network resources names being created. | `string` | `null` | no |
| runtime | The runtime in which the function will be executed. | `string` | n/a | yes |
| secret\_environment\_variables | A list of maps which contains key, project\_id, secret\_name (not the full secret id) and version to assign to the function as a set of secret environment variables. | <pre>set(object({<br>    key_name   = string<br>    project_id = optional(string)<br>    secret     = string<br>    version    = string<br>  }))</pre> | `null` | no |
| secret\_volumes | [Beta] Environment variables (Secret Manager). | <pre>set(object({<br>    mount_path = string<br>    project_id = optional(string)<br>    secret     = string<br>    versions = set(object({<br>      version = string<br>      path    = string<br>    }))<br>  }))</pre> | `null` | no |
| serverless\_project\_id | The project to deploy the cloud function service. | `string` | n/a | yes |
| serverless\_project\_number | The project number to deploy to. | `number` | `null` | no |
| service\_account\_email | Service account to be used on Cloud Function. | `string` | n/a | yes |
| shared\_vpc\_name | Shared VPC name which is going to be re-used to create Serverless Connector. | `string` | n/a | yes |
| storage\_source | Get the source from this location in Google Cloud Storage. | <pre>object({<br>    bucket     = string<br>    object     = string<br>    generation = optional(string, null)<br>  })</pre> | `null` | no |
| subnet\_name | Subnet name to be re-used to create Serverless Connector. | `string` | `null` | no |
| timeout\_seconds | Timeout for each request. | `number` | `120` | no |
| vpc\_egress\_value | Sets VPC Egress firewall rule. Supported values are VPC\_CONNECTOR\_EGRESS\_SETTINGS\_UNSPECIFIED, PRIVATE\_RANGES\_ONLY, and ALL\_TRAFFIC. | `string` | `"ALL_TRAFFIC"` | no |
| vpc\_project\_id | The host project for the shared vpc. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cloud\_services\_sa | Service Account for Cloud Function. |
| cloudfunction\_bucket | The Cloud Function source bucket. |
| cloudfunction\_bucket\_name | The Cloud Function source bucket. |
| cloudfunction\_name | ID of the created Cloud Function. |
| cloudfunction\_url | Url of the created Cloud Function. |
| connector\_id | VPC serverless connector ID. |
| gca\_vpcaccess\_sa | Service Account for VPC Access. |
| key\_self\_link | Name of the Cloud KMS crypto key. |
| keyring\_self\_link | Name of the Cloud KMS keyring. |
| serverless\_identity\_services\_sa | Service Identity to serverless services. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

### Software

The following dependencies must be available:

* [Terraform](https://www.terraform.io/downloads.html) >= 1.3
* [Terraform Provider for GCP](https://github.com/terraform-providers/terraform-provider-google) < 5.0

### APIs

The Secure-cloud-function module will enable the following APIs to the Serverless Project:

* Serverless Project
  * Container Scanning: `containerscanning.googleapis.com`

### Service Account

A service account with the following roles must be used to provision
the resources of this module:

* VPC Project
  * Compute Shared VPC Admin: `roles/compute.xpnAdmin`
  * Network Admin: `roles/compute.networkAdmin`
  * Security Admin: `roles/compute.securityAdmin`
  * Serverless VPC Access Admin: `roles/vpcaccess.admin`
* KMS Project
  * Cloud KMS Admin: `roles/cloudkms.admin`
* Serverless Project
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
  * Organization Policy Administrator: `roles/orgpolicy.policyAdmin`
  * Project IAM Admin: `roles/resourcemanager.projectIamAdmin`
