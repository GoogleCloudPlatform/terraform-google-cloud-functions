# Secure Cloud Function With Internal Server Example

This example shows how to deploy a Secure Cloud Function (2nd Gen) that communicates with an internal webserver using Shared VPC and multiple projects.

The resources and services that this example will create or enable are:

* The **secure-serverless-harness** module will:
  * Create a Security Project
  * Create a Cloud Function project
  * Create a Shared VPC Project with:
    * A Shared Network
    * A firewall rule to deny all egress traffic
    * A firewall rule to allow internal APIs traffic
    * A configured Private Connect

* The **secure-serverless-network** module will:
  * Create the following Firewall rules on the **Shared VPC Project**:
    * Serverless to VPC Connector
    * VPC Connector to Serverless
    * VPC Connector Health Checks
  * Create a sub network to VPC Connector usage purpose
  * Create a Serverless Connector on the **Shared VPC Project** or the **Serverless Project**. Refer to the following comparison to choose where to create Serverless Connector:
    * Advantages of creating connectors in the [VPC Project](https://cloud.google.com/run/docs/configuring/connecting-shared-vpc#host-project)
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
  * Upload your certificate manager
    * You can use a self-signed
  * Create a Gateway Security Policy with:
    * A Gateway Security Policy Rule
    * A Security URL Lists resource
  * Create the Secure Web Proxy/Gateway (SWP/SWG) instance

_Note: Please refer to [Secure Web Proxy documentation](../../docs/secure-web-proxy.md) for more details about pricing and how manually delete it._

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

* In addition to all the secure-cloud-function resources created, this example will also create:
  * A Webserver Instance
  * A startup script will be added in the internal server to create the Webserver using Python code
  * A Storage Bucket to store Cloud Function source Code
  * A Firewall rule to allow to connect on Webserver using Private IP

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

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

To provision this example, run the following commands from within this directory:

* `mv terraform.tfvars.example terraform.tfvars` to rename the example `tfvars` file.
* Fill the `terraform.tfvars` with your values.
* `terraform init` to get the plugins.
* `terraform plan` to see the infrastructure plan.
* `terraform apply` to apply the infrastructure build.
* `terraform destroy` to destroy the built infrastructure.

### Testing

You can see the Secure Cloud Function running, uploading a file on the bucket.

* Go to [Cloud Storage console](https://console.cloud.google.com/storage/).
* Select your Serverless project.
* Select the bucket with pattern `bkt-<LOCATION>-<PROJECT-NUMBER>-cfv2-zip-files`.
* Upload a file.
* Go to the [Cloud Function console](https://console.cloud.google.com/functions).
* Select your project and Cloud Function.
* Go to the logs.
* When upload is done, you can see the Cloud Function accessing the internal server logs.

If you want to look at the WebServer logs you can:

#### Use Cloud Logging

* Go the the [Compute instances console](https://console.cloud.google.com/compute/instances).
* Select the serverless project.
* Go to More Actions and click in View Logs.
* When a file is upload at the bucket, Cloud Function will hit the internal server and a `Hello World log` will appear.

```sh
2023/07/06 17:21:49 Message returned from internal server: ----------- hello world --------------
```

```sh
startup-script: 10.0.0.4 - - [06/Jul/2023 17:21:49] "GET /index.html HTTP/1.1" 200 -
```

#### Do SSH to internal server machine

* Enable a firewall rule to allow SSH at Web server machine:

```sh
gcloud compute firewall-rules create allow-ssh-ingress-from-iap \
--direction=INGRESS \
--action=allow \
--rules=tcp:22 \
--source-ranges=35.235.240.0/20 \
--network=<YOUR-NETWORK> \
--project=<YOUR-NETWORK-PROJECT>
```

* Grant `IAP-secured Tunnel User` role at your user, at Web Server project:

```sh
gcloud projects add-iam-policy-binding <YOUR-SERVERLESS-PROJECT-ID> \
--member=user:<YOUR-USER-EMAIL> \
--role=roles/iap.tunnelResourceAccessor
```

* Go the the [Compute instances console](https://console.cloud.google.com/compute/instances).
* Select the serverless project.
* Click at SSH button.
* When the VM console open, execute:

```sh
tail -f /tmp/request_logs.log
```

* You can upload a new file at the bucket, and see new logs at WebServer and Cloud Function.

```sh
2023/07/06 17:21:49 Message returned from internal server: ----------- hello world --------------
```

```sh
startup-script: 10.0.0.4 - - [06/Jul/2023 17:21:49] "GET /index.html HTTP/1.1" 200 -
```

_**Note:** Disable the firewall rule after your tests: `gcloud compute firewall-rules update allow-ssh-ingress-from-iap --disabled --project="<YOUR-NETWORK-PROJECT>" --quiet`_

## Requirements

### Software

The following dependencies must be available:

* [Terraform](https://www.terraform.io/downloads.html) >= 1.3
* [Terraform Provider for GCP](https://github.com/terraform-providers/terraform-provider-google) < 5.0

### APIs

The Secure Cloud Function Internal Server Example will enable the following APIs to the Serverless Project:

* Artifact Registry API: `artifactregistry.googleapis.com`
* Cloud Build API: `cloudbuild.googleapis.com`
* Cloud Function API: `cloudfunctions.googleapis.com`
* Cloud Run API: `run.googleapis.com`
* Cloud KMS API: `cloudkms.googleapis.com`
* Compute API: `compute.googleapis.com`
* Config Monitoring for Ops API: `opsconfigmonitoring.googleapis.com`
* Container Registry API: `container.googleapis.com`
* Container Scanning API: `containerscanning.googleapis.com`
* Google VPC Access API: `vpcaccess.googleapis.com`
* Eventarc API: `eventarc.googleapis.com`
* Eventarc Publishing API: `eventarcpublishing.googleapis.com`
* Service Networking API: `servicenetworking.googleapis.com`

The Secure Cloud Function with Internal Server Example will enable the following APIs to the VPC Project:

* Compute API: `compute.googleapis.com`
* DNS API: `dns.googleapis.com`
* Google VPC Access API: `vpcaccess.googleapis.com`
* Service Networking API: `servicenetworking.googleapis.com`

The Secure Cloud Function with Internal Server Example will enable the following APIs to the Security Project:

* Artifact Registry API: `artifactregistry.googleapis.com`
* Cloud KMS API: `cloudkms.googleapis.com`

### Service Account

A service account with the following roles must be used to provision the resources of this module:

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
