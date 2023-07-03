# Secure Cloud Function Triggered by BigQuery

This examples shows how trigger Secure Cloud Function (2nd Gen) by BigQuery.

The resources and services that this example will create or enable are:

* The **secure-serverless-harness** module will:
  * Create a Security Project with the following APIS enabled:
    * Cloud KMS API: `cloudkms.googleapis.com`
  * Create a Cloud Function project with the following APIS enabled:
    * Google VPC Access API: `vpcaccess.googleapis.com`
    * Compute API: `compute.googleapis.com`
    * Container Registry API: `container.googleapis.com`
    * Cloud Function API: `run.googleapis.com`
  * Create a Shared VPC Project with:
    * A Shared Network
    * A firewall rule to deny all egress traffic
    * A firewall rule to allow Internal APIs traffic
    * A configured Private Connect
    * And the following APIs enabled:
      * Google VPC Access API: `vpcaccess.googleapis.com`
      * Compute API: `compute.googleapis.com`

* The **secure-serverless-network** module will:
  * Create the following Firewall rules on the **Shared VPC Project**.
    * Serverless to VPC Connector
    * VPC Connector to Serverless
    * VPC Connector Health Checks
  * Create a a sub network to VPC Connector usage purpose.
  * Create a Serverless Connector on the **Shared VPC Project** or **Serverless Project**. Refer to the following comparison to choose where to create Serverless Connector:
    * Advantages of creating connectors in the [Shared VPC Project](https://cloud.google.com/run/docs/configuring/connecting-shared-vpc#host-project)
    * Advantages of creating connectors in the [Serverless Project](https://cloud.google.com/run/docs/configuring/connecting-shared-vpc#service-projects)
  * Grant the necessary roles for the Cloud Function to be able to use the VPC Connector on the Shared VPC if creating the VPC Connector in the host project:
    * Grant Network User role to the [Google API Service Agent](https://cloud.google.com/compute/docs/access/service-accounts#google_apis_service_agent) service account.
    * Grant VPC Access User to the [Google Cloud Functions Service Agent](https://cloud.google.com/functions/docs/concepts/iam#access_control_for_service_accounts) when deploying VPC Access.

* The **secure-web-proxy** module will:
  * Create a sub network for Regional Managed Proxy purpose
  * Create the following Firewall rule on the **Shared VPC Project**:
    * Cloud Build to Secure Web Proxy
  * Create a VPC peering for the Shared VPC Network with:
    * A Compute Global Address
    * A Service Networking Connection
  * Upload an example generated self-signed certificate to Certificate Manager
  * Create a Gateway Security Policy with:
    * A Gateway Security Policy Rule
    * A Security URL Lists resource
  * Create the Secure Web Proxy/Gateway (SWP/SWG) instance

_Note: Please refer to [Secure Web Proxy documentation](../../docs/secure-web-proxy.md) for more details about pricing and how manually to delete it._

* The **secure-cloud-serverless-security** module will:
  * Create KMS Keyring and Key for [customer managed encryption keys](https://cloud.google.com/run/docs/securing/using-cmek) in the **KMS Project** to be used by Cloud Function (2nd Gen)
  * Enable the following Organization Policies related to Cloud Function (2nd Gen) in the **Serverless Project**:
    * Allowed ingress settings - Allow HTTP traffic from private VPC sources and through GCLB.
    * Allowed VPC Connector egress settings - Force the use of VPC Access Connector for all egress traffic from the function.
  * Grant the following roles if groups emails are provided:
    * **Serverless Administrator** group on the Service Project:
      * Cloud Run Admin: `roles/run.admin`
      * Cloud Functions Admin: `roles/cloudfunctions.admin`
      * Network Viewer: `roles/compute.networkViewer`
      * Network User: `roles/compute.networkUser`
    * **Servervless Security Administrator** group on the Security project:
      * Cloud Functions Viewer: `roles/cloudfunctions.viewer`
      * Cloud Frun Viewer: `roles/run.viewer`
      * Cloud KMS Viewer: `roles/cloudkms.viewer`
      * Artifact Registry Reader: `roles/artifactregistry.reader`
    * **Cloud Function (2nd Gen) developer** group on the Security project:
      * Cloud Functions Developer: `roles/cloudfunctions.developer`
      * Artifact Registry Writer: `roles/artifactregistry.writer`
      * Cloud KMS CryptoKey Encrypter: `roles/cloudkms.cryptoKeyEncrypter`
    * **Cloud Function (2nd Gen) user** group on the Service project:
      * Cloud Functions Invoker: `roles/cloudfunctions.invoker`

* The **secure-cloud-function-core** module will:
  * Create a Cloud Function (2nd Gen)
  * Create the Cloud Function source bucket in the same location as the Cloud Function
  * Configure the EventArc Google Channel to use Customer Encryption Key in the Cloud Function location
    * **Warning:** If there is another CMEK configured for the same region, it will be overwritten
  * Create a private worker pool for Cloud Build configured to not use External IP
  * Grant Cloud Functions Invoker to the [EventArc Trigger Service Account](https://cloud.google.com/functions/docs/calling/eventarc#trigger-identity)
  * Enable [Container Registry Automatic Scanning](https://cloud.google.com/artifact-registry/docs/analysis)

* In addition to all the secure-cloud-function resources created, this example will also create::
  * BigQuery Dataset
  * BigQuery Table
  * Storage Bucket to store Cloud Function source Code
  * KMS Keys to be used by:
    * Pub/Sub Topic
    * BigQuery Dataset and Table

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

To provision this example, run the following commands from within this directory:

* `mv terraform.tfvars.example terraform.tfvars` to rename the example `tfvars` file.
* Fill the `terraform.tfvars` with your values.
* `terraform init` to get the plugins.
* `terraform plan` to see the infrastructure plan.
* `terraform apply` to apply the infrastructure build.
* `terraform destroy` to destroy the built infrastructure.

### Testing

You can see the Secure Cloud Function running, doing an insert at Bigquery table.

* Go to [BigQuery console](https://console.cloud.google.com/bigquery)
* Select your Serverless project
* Create a new Query
* Run the following INSERT command

```sql
INSERT INTO `<YOUR-PROJECT-ID>.dst_secure_cloud_function.tbl_test` VALUES
("AX","American Express","American Express","30006041298416","Gerson Beahan","688","09/2008","04/2013","26",9287,"77443")
```

* Go to the [Cloud Function console](https://console.cloud.google.com/functions)
* Select your Serverless project and Cloud Function
* Go to the logs
* When the insert is done, you can see the logs with the buckets and regions at your Serverless Project Cloud Function Logs.

## Requirements

### Software

The following dependencies must be available:

* [Terraform](https://www.terraform.io/downloads.html) >= 1.3
* [Terraform Provider for GCP](https://github.com/terraform-providers/terraform-provider-google) < 5.0
* [Google Cloud SDK CLI](https://cloud.google.com/sdk/docs/install) > 428.0.0

### APIs

### Required APIs enabled at Service Account project

The service account project must have the following APIs enabled:

* Access Context Manager API: `accesscontextmanager.googleapis.com`
* Cloud Billing API: `cloudbilling.googleapis.com`
* Cloud Build API: `cloudbuild.googleapis.com`
* Cloud Key Management Service (KMS) API: `cloudkms.googleapis.com`
* Cloud Pub/Sub API: `pubsub.googleapis.com`
* Cloud Resource Manager API: `cloudresourcemanager.googleapis.com`
* Identity and Access Management (IAM) API: `iam.googleapis.com`
* Service Networking API: `servicenetworking.googleapis.com`

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
* Billing:
  * Billing User: `roles/billing.user`
