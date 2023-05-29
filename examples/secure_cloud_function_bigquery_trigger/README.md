# Secure Cloud Function Triggered by BigQuery

This examples shows how trigger Cloud Function (2nd Gen) by BigQuery

The resources/services/activations/deletions that this example will create/trigger are:

* secure-serverless-harness module will apply:
  * Creates Security Project
  * Creates Shared VPC Project
    * Creates Shared Network
    * Deny all Egress Rule
    * Allow Internal APIs Firewall Rule
    * Configure Private Connect
  * Creates Cloud Function project

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

* secure-web-proxy module will apply:
  * Creates a sub network to Regional Managed Proxy purpose.
  * Creates Firewall rules on your **VPC Project**.
    * Cloud Build to Secure Web Proxy
  * Creates a VPC peering for your network.
    * Global address
    * Networking Connection
  * Uploads your certificate manager.
    * You can use a self-signed.
  * Creates a Gateway Security Policy Rule.
    * Creates a Gateway Security Policy.
    * Creates a Security URL Lists.
  * Creates the Secure Web Proxy/Gateway (SWP/SWG) instance.

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
  * BigQuery Dataset
  * BigQuery Table
  * Storage Bucket to store Cloud Function source Code
  * KMS Keys to be used by:
    * Pub/Sub
    * BigQuery

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
| swp\_certificate\_id | The certificate id to be used on the Secure Web Proxy Gateway. | `string` | n/a | yes |
| terraform\_service\_account | The e-mail of the service account who will impersionate when creating infrastructure. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| bigquery\_kms\_key | KMS Key used in the Bigquery dataset. |
| cloud\_function\_name | The service account email created to be used by Cloud Function. |
| cloudfunction\_bucket | The Cloud Function source bucket. |
| cloudfunction\_bucket\_name | Name of the Cloud Function source bucket. |
| cloudfunction\_url | The URL on which the deployed service is available. |
| connector\_id | VPC serverless connector ID. |
| network\_project\_id | The network project id. |
| restricted\_access\_level\_name | Access level name. |
| restricted\_service\_perimeter\_name | Service Perimeter name. |
| security\_project\_id | The security project id. |
| security\_project\_number | The security project number. |
| serverless\_project\_id | The serverless project id. |
| serverless\_project\_number | The serverless project number. |
| service\_account\_email | The service account email created to be used by Cloud Function. |
| service\_vpc\_name | The Network self-link created in harness. |
| service\_vpc\_self\_link | The Network self-link created in harness. |
| service\_vpc\_subnet\_name | The sub-network name created in harness. |
| table\_id | Bigquery table name. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

### Software

The following dependencies must be available:

* [Terraform](https://www.terraform.io/downloads.html) >= 0.13.0
* [Terraform Provider for GCP](https://github.com/terraform-providers/terraform-provider-google) < 5.0

### APIs

The Secure-cloud-function module will enable the following APIs to the Serverlesss Project:

* Google VPC Access API: `vpcaccess.googleapis.com`
* Compute API: `compute.googleapis.com`
* Container Registry API: `container.googleapis.com`
* Cloud Function API: `run.googleapis.com`

The Secure-cloud-function module will enable the following APIs to the VPC Project:

* Google VPC Access API: `vpcaccess.googleapis.com`
* Compute API: `compute.googleapis.com`

The Secure-cloud-function module will enable the following APIs to the KMS Project:

* Cloud KMS API: `cloudkms.googleapis.com`

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
  * Security Admin: `roles/compute.securityAdmin`
  * Serverless VPC Access Admin: `roles/vpcaccess.admin`
  * Cloud Function Developer: `roles/run.developer`
  * Compute Network User: `roles/compute.networkUser`
  * Artifact Registry Reader: `roles/artifactregistry.reader`

**Note:** [Secret Manager Secret Accessor](https://cloud.google.com/run/docs/configuring/secrets#access-secret) role must be granted to the Cloud Function service account to allow read access on the secret.
