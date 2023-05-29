# Secure Cloud Function With Cloud SQL Example

This examples shows how to connect Secure Cloud Function (2nd Gen) with Cloud SQL in different project
using a Shared VPC and multiple projects.

The resources/services/activations/deletions that this example will create/trigger are:

* secure-serverless-harness module will apply:
  * Creates Security Project
  * Creates Shared VPC Project
    * Creates Shared Network
    * Deny all Egress Rule
    * Allow Internal APIs Firewall Rule
    * Configure Private Connect
  * Creates Cloud Function project
  * Creates Cloud SQL project

* secure-serverless-network module will apply:
  * Creates Firewall rules on your **VPC Project**.
    * Serverless to VPC Connector
    * VPC Connector to Serverless
    * VPC Connector Health Checks
  * Creates a sub network to VPC Connector usage purpose.
  * Creates Serverless Connector on your **VPC Project** or **Serverless Project**. Refer the comparison below:
    * Advantages of creating connectors in the [VPC Project](https://cloud.google.com/run/docs/configuring/connecting-shared-vpc#host-project)
    * Advantages of creating connectors in the [Serverless Project](https://cloud.google.com/run/docs/configuring/connecting-shared-vpc#service-projects)
  * Grant the necessary roles for Cloud Function are able to use VPC Connector on your Shared VPC when creating VPC Connector in host project.
    * Grant Network User role to Cloud Services service account.
    * Grant VPC Access User to Cloud Function Service Identity when deploying VPC Access.

* secure-cloud-serverless-security module will apply:
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
  * Enables Container Registry Automatic Scanning.

* The Example will create besides all secure-cloud-function resources:
  * Cloud SQL Private Access
  * Cloud SQL Instance
  * Cloud SQL MYSQL database
  * Storage Bucket to store Cloud Function source Code
  * KMS Keys to be used by:
    * Pub/Sub
    * Cloud SQL
    * Secret Manager
  * Cloud Scheduler
  * Pub/Sub Topic
  * Secret Manager
  * Cloud SQL User
  * Secret Manager version saving Database user password
  * Firewall rule to allow to connect on Cloud SQL using Private IP
  * Import a sample database

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_context\_manager\_policy\_id | The id of the default Access Context Manager policy. Can be obtained by running `gcloud access-context-manager policies list --organization YOUR_ORGANIZATION_ID --format="value(name)"`. This variable must be provided if `create_access_context_manager_access_policy` is set to `false` | `number` | `null` | no |
| access\_level\_members | The list of members who will be in the access level. | `list(string)` | n/a | yes |
| billing\_account | The ID of the billing account to associate this project with. | `string` | n/a | yes |
| create\_access\_context\_manager\_access\_policy | Defines if Access Context Manager will be created by Terraform. If set to `false`, you must provide `access_context_manager_policy_id`. More information about Access Context Manager creation in [this documentation](https://cloud.google.com/access-context-manager/docs/create-access-level). | `bool` | n/a | yes |
| egress\_policies | A list of all [egress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#egress-rules-reference), each list object has a `from` and `to` value that describes egress\_from and egress\_to.<br><br>Example: `[{ from={ identities=[], identity_type="ID_TYPE" }, to={ resources=[], operations={ "SRV_NAME"={ OP_TYPE=[] }}}}]`<br><br>Valid Values:<br>`ID_TYPE` = `null` or `IDENTITY_TYPE_UNSPECIFIED` (only allow indentities from list); `ANY_IDENTITY`; `ANY_USER_ACCOUNT`; `ANY_SERVICE_ACCOUNT`<br>`SRV_NAME` = "`*`" (allow all services) or [Specific Services](https://cloud.google.com/vpc-service-controls/docs/supported-products#supported_products)<br>`OP_TYPE` = [methods](https://cloud.google.com/vpc-service-controls/docs/supported-method-restrictions) or [permissions](https://cloud.google.com/vpc-service-controls/docs/supported-method-restrictions). | <pre>list(object({<br>    from = any<br>    to   = any<br>  }))</pre> | `[]` | no |
| folder\_id | The ID of a folder to host the infrastructure created in this example. | `string` | `""` | no |
| ingress\_policies | A list of all [ingress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#ingress-rules-reference), each list object has a `from` and `to` value that describes ingress\_from and ingress\_to.<br><br>Example: `[{ from={ sources={ resources=[], access_levels=[] }, identities=[], identity_type="ID_TYPE" }, to={ resources=[], operations={ "SRV_NAME"={ OP_TYPE=[] }}}}]`<br><br>Valid Values:<br>`ID_TYPE` = `null` or `IDENTITY_TYPE_UNSPECIFIED` (only allow indentities from list); `ANY_IDENTITY`; `ANY_USER_ACCOUNT`; `ANY_SERVICE_ACCOUNT`<br>`SRV_NAME` = "`*`" (allow all services) or [Specific Services](https://cloud.google.com/vpc-service-controls/docs/supported-products#supported_products)<br>`OP_TYPE` = [methods](https://cloud.google.com/vpc-service-controls/docs/supported-method-restrictions) or [permissions](https://cloud.google.com/vpc-service-controls/docs/supported-method-restrictions). | <pre>list(object({<br>    from = any<br>    to   = any<br>  }))</pre> | `[]` | no |
| org\_id | The organization ID. | `string` | n/a | yes |
| terraform\_service\_account | The e-mail of the service account who will impersionate when creating infrastructure. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cloud\_function\_name | The service account email created to be used by Cloud Function. |
| cloud\_sql\_kms\_key | The KMS Key create to encrypt Cloud SQL. |
| cloudfunction\_bucket | The Cloud Function source bucket. |
| cloudfunction\_bucket\_name | Name of the Cloud Function source bucket. |
| cloudfunction\_url | The URL on which the deployed service is available. |
| cloudsql\_project\_id | The Cloud SQL project id. |
| connector\_id | VPC serverless connector ID. |
| mysql\_conn | The connection name of the master instance to be used in connection strings. |
| mysql\_name | The name for Cloud SQL instance. |
| mysql\_private\_ip\_address | The first private (PRIVATE) IPv4 address assigned for the master instance. |
| mysql\_public\_ip\_address | The first public (PRIMARY) IPv4 address assigned for the master instance. |
| mysql\_user | The user created in database instance. |
| network\_project\_id | The network project id. |
| restricted\_access\_level\_name | Access level name. |
| restricted\_service\_perimeter\_name | Service Perimeter name. |
| scheduler\_name | Cloud Scheduler Job name. |
| secret\_kms\_key | The KMS Key create to encrypt Secrets. |
| secret\_manager\_id | Secret Manager id created to store Database password. |
| secret\_manager\_name | Secret Manager name created to store Database password. |
| secret\_manager\_version | Secret Manager version created to store Database password. |
| security\_project\_id | The security project id. |
| security\_project\_number | The security project number. |
| serverless\_project\_id | The serverless project id. |
| serverless\_project\_number | The serverless project number. |
| service\_account\_email | The service account email created to be used by Cloud Function. |
| service\_vpc\_name | The Network self-link created in harness. |
| service\_vpc\_self\_link | The Network self-link created in harness. |
| service\_vpc\_subnet\_name | The sub-network name created in harness. |
| topic\_id | The Pub/Sub topic which will trigger Cloud Function. |
| topic\_kms\_key | The KMS Key create to encrypt Pub/Sub Topic messages. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

### Software

The following dependencies must be available:

* [Terraform](https://www.terraform.io/downloads.html) >= 1.3
* [Terraform Provider for GCP](https://github.com/terraform-providers/terraform-provider-google) < 5.0

### APIs

The Secure Cloud Function with Cloud SQL Example will enable the following APIs to the Serverless Project:

* Google VPC Access API: `vpcaccess.googleapis.com`
* Compute API: `compute.googleapis.com`
* Container Registry API: `container.googleapis.com`
* Artifact Registry API: `artifactregistry.googleapis.com`
* Cloud Function API: `cloudfunctions.googleapis.com`
* Cloud Run API: `run.googleapis.com`
* Service Networking API: `servicenetworking.googleapis.com`
* SQL Admin API: `sqladmin.googleapis.com`
* Cloud KMS API: `cloudkms.googleapis.com`
* Cloud Scheduler API: `cloudscheduler.googleapis.com`
* Container Scanning API: `containerscanning.googleapis.com`
* Eventarc API: `eventarc.googleapis.com`
* Eventarc Publishing API: `eventarcpublishing.googleapis.com`
* Cloud Build API: `cloudbuild.googleapis.com`

The Secure Cloud Function with Cloud SQL Example will enable the following APIs to the Cloud SQL Project:

* Google VPC Access API: `vpcaccess.googleapis.com`
* Compute API: `compute.googleapis.com`
* Container Registry API: `container.googleapis.com`
* Cloud Function API: `run.googleapis.com`
* Service Networking API: `servicenetworking.googleapis.com`
* SQL Admin API: `sqladmin.googleapis.com`
* SQL Component API: `sql-component.googleapis.com`

The Secure Cloud Function with Cloud SQL Example will enable the following APIs to the VPC Project:

* Google VPC Access API: `vpcaccess.googleapis.com`
* Compute API: `compute.googleapis.com`
* Service Networking API: `servicenetworking.googleapis.com`
* DNS API: `dns.googleapis.com`

The Secure Cloud Function with Cloud SQL Example will enable the following APIs to the Security Project:

* Cloud KMS API: `cloudkms.googleapis.com`
* Secret Manager API: `secretmanager`
* Artifact Registry API: `artifactregistry.googleapis.com`

### Service Account

A service account with the following roles must be used to provision
the resources of this module:

* Organization Level
  * Access Context Manager Admin: `roles/accesscontextmanager.policyAdmin`
  * Organization Policy Admin: `roles/orgpolicy.policyAdmin`
* Folder Level:
  * Folder Admin: `roles/resourcemanager.folderAdmin`
  * Project Creator: `roles/resourcemanager.projectCreator`
  * Project Deleter: `roles/resourcemanager.projectDeleter`
  * Compute Shared VPC Admin: `roles/compute.xpnAdmin`
