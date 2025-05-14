# How to customize Foundation v3.0.0 for Secure Cloud Function deployment

This example deploys the [Secure Cloud Function](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/tree/main/modules/secure-cloud-function) on top of the [Terraform Example Foundation](https://cloud.google.com/architecture/security-foundations/using-example-terraform) version [3.0.0](https://github.com/terraform-google-modules/terraform-example-foundation/tree/v3.0.0).

This example will use the `production` environment of the business unit 1 and will:

* Create two new projects under each environment folder and each business unit (bu1/bu2) for Secure Cloud Function within the foundation infrastructure.
* Attach the projects to the Restricted Shared VPC foundation network.
* Deploy Secure Cloud Function with with a function that receive events from [Eventarc](https://cloud.google.com/eventarc/docs).
* Create a BigQuery Dataset and Table.
* Create a BigQuery Eventarc trigger for insertions on the BigQuery Table.
* Create a Serverless VPC Connector on the serverless project.

## Requirements

* [terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation/tree/v3.0.0) version 3.0.0 deployed until at least step `4-projects`.
* You must have role **Service Account User** (`roles/iam.serviceAccountUser`) on the [Terraform Service Accounts](https://github.com/terraform-google-modules/terraform-example-foundation/blob/master/docs/GLOSSARY.md#terraform-service-account) created in the foundation [Seed Project](https://github.com/terraform-google-modules/terraform-example-foundation/blob/master/docs/GLOSSARY.md#seed-project).
  The Terraform Service Accounts have the permissions to deploy the foundation on each stage.
    * `sa-terraform-bootstrap@<SEED_PROJECT_ID>.iam.gserviceaccount.com`.
    * `sa-terraform-org@<SEED_PROJECT_ID>.iam.gserviceaccount.com`.
    * `sa-terraform-env@<SEED_PROJECT_ID>.iam.gserviceaccount.com`.
    * `sa-terraform-net@<SEED_PROJECT_ID>.iam.gserviceaccount.com`.
    * `sa-terraform-proj@<SEED_PROJECT_ID>.iam.gserviceaccount.com`.

## Usage

The following instructions details the changes needed in the foundation Terraform configuration to deploy the Secure Cloud Function.
You will do updates in sequence in the configurations of the steps used to the deploy the foundation.

### Directory layout and Terraform initialization

For these instructions we assume that:

1. The foundation was deployed using Cloud Build.
1. Every repository, excluding the policies repositories, should be on the `production` branch and `terraform init` should be executed in each one.
1. The following layout exists in your local environment since you will need to make changes in these steps.
If you do not have this layout, please checkout the source repositories for the foundation steps following this layout.

    ```text
    gcp-bootstrap
    gcp-environments
    gcp-networks
    gcp-org
    gcp-policies
    gcp-policies-app-infra
    gcp-projects
    terraform-example-foundation
    ```

1. Also checkout the `terraform-google-cloud-functions` repo at the same level.

The final layout should look like this:

```text
gcp-bootstrap
gcp-environments
gcp-networks
gcp-org
gcp-policies
gcp-policies-app-infra
gcp-projects
terraform-example-foundation
terraform-google-cloud-functions
```

### Update builder image

1. Go to the trigger page in Google Cloud Console

      ```bash
      terraform -chdir="./gcp-bootstrap/envs/shared" init
      export DEFAULT_REGION=$(terraform -chdir="./gcp-bootstrap/envs/shared" output -json common_config | jq '.default_region' --raw-output)
      export CICD_PROJECT_ID=$(terraform -chdir="./gcp-bootstrap/envs/shared" output -raw cloudbuild_project_id)

      echo "trigger page = https://console.cloud.google.com/cloud-build/triggers;region=${DEFAULT_REGION}?project=${CICD_PROJECT_ID}"
      ```

1. In the trigger page search for the line with the trigger with name `tf-cloud-builder-build` and description *Builds a Terraform runner image. Managed by Terraform.*
1. Select the `RUN` option.
1. On the pop-up select the `RUN TRIGGER` button.
1. Wait for the build to finish.

### Update gcloud terraform vet policies

the first step is to update the `gcloud terraform vet` policies constraints to allow usage of the APIs needed by the Secure Cloud Function.
The constraints are located in the two policies repositories. Following the instructions for the Cloud Cloud deploy, they would be named:

* `gcp-policies`
* `gcp-policies-app-infra`

The APIs to add are:

```yaml
    - "cloudfunctions.googleapis.com"
    - "eventarc.googleapis.com"
    - "eventarcpublishing.googleapis.com"
    - "run.googleapis.com"
    - "vpcaccess.googleapis.com"
    - "containerscanning.googleapis.com"
    - "certificatemanager.googleapis.com"
    - "networkservices.googleapis.com"
    - "networksecurity.googleapis.com"
```

1. The APIs should be included in the `services` list in the file [serviceusage_allow_basic_apis.yaml](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/policy-library/policies/constraints/serviceusage_allow_basic_apis.yaml#L30)
1. Update `gcp-policies/policies/constraints/serviceusage_allow_basic_apis.yaml` file in your policy repository (gcp-policies) for the CI/CD pipeline.
1. It is also necessary to update the file `gcp-policies/policies/templates/gcp_network_enable_flow_logs_v1.yaml` to allow the creation of subnetworks of purpose type `REGIONAL_MANAGED_PROXY`. Replace the existing section of the code block with the following version.

    ```yaml

              network := asset.resource.data
              legacy_enable_flow_logs := lib.get_default(network, "enableFlowLogs", false)
              log_config := lib.get_default(network, "logConfig", {})
              log_config_enable_flow_logs := lib.get_default(log_config, "enable", false)
              purpose := lib.get_default(network, "purpose", "PRIVATE")

              log_config_enable_flow_logs != true
              legacy_enable_flow_logs != true
              purpose != "REGIONAL_MANAGED_PROXY"

    ```

1. Commit changes in the `gcp-policies` repository and push the code.
1. Update `gcp-policies-app-infra/policies/constraints/serviceusage_allow_basic_apis.yaml` file in your policy repository (gcp-policies-app-infra) for the App Infra pipeline.
1. Update `gcp-policies-app-infra/policies/templates/gcp_network_enable_flow_logs_v1.yaml` file in your policy repository (gcp-policies-app-infra) for the App Infra pipeline.
1. Commit changes in the `gcp-policies-app-infra` repository and push the code.

### 1-org: Enforce Cloud Function Organization Policies

The Secure Cloud Function requires five Organization Policies related to Cloud Function and Cloud Run:

* Require VPC Connector (Cloud Functions)
* Allowed ingress settings (Cloud Functions)
* Allowed VPC Connector egress settings (Cloud Functions)
* Allowed ingress settings (Cloud Run)
* Allowed VPC egress settings (Cloud Run)

For the Terraform Example Foundation deploy, we will use the `terraform-google-modules/org-policy/google` [module](https://registry.terraform.io/modules/terraform-google-modules/org-policy/google/latest)
instead of the specific Secure Cloud Function Security [module](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/tree/main/modules/secure-cloud-function-security) because the Secure Cloud Function Security module also creates KMS resources.

To apply these Organization Policies in Parent Level (Organization or Folder level), add the code below in the `gcp-org` repository.

**Note:** You can also apply these Organization Policies to the folder `production` or directly to the projects that will be created for the Secure Cloud Function.
If you want to apply to the Secure Cloud Function projects, this step must be applied after step [4-projects: Create Serverless project, security project, and additional harness in the production environment](#4-projects-create-serverless-project-security-project-and-additional-harness-in-the-production-environment).
See the [org-policy module](https://github.com/terraform-google-modules/terraform-google-org-policy/tree/master#variables) documentation on how to apply the policies to projects.

1. Add Organization Policies related to Secure Cloud Function at `gcp-org/envs/shared/org_policy.tf`

    1. Boolean policy: Add policy `"cloudfunctions.requireVPCConnector"` to the [boolean_type_organization_policies](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/1-org/envs/shared/org_policy.tf#LL27C1-L43C5) list:

        ```hcl
          boolean_type_organization_policies = toset([
            "compute.disableNestedVirtualization",
            "compute.disableSerialPortAccess",
            "compute.disableGuestAttributesAccess",
            "compute.skipDefaultNetworkCreation",
            "compute.restrictXpnProjectLienRemoval",
            "compute.disableVpcExternalIpv6",
            "compute.setNewProjectDefaultToZonalDNSOnly",
            "compute.requireOsLogin",
            "sql.restrictPublicIp",
            "sql.restrictAuthorizedNetworks",
            "iam.disableServiceAccountKeyCreation",
            "iam.automaticIamGrantsForDefaultServiceAccounts",
            "iam.disableServiceAccountKeyUpload",
            "storage.uniformBucketLevelAccess",
            "storage.publicAccessPrevention",
            "cloudfunctions.requireVPCConnector"
          ])
        ```

    1. List policies: Copy the following code to the same file [org_policy.tf](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/1-org/envs/shared/org_policy.tf)

      ```hcl
      /******************************************
      Cloud Function
      *******************************************/

      module "cloudfunction_allowed_ingress" {
        source  = "terraform-google-modules/org-policy/google"
        version = "~> 5.1"

        organization_id   = local.organization_id
        folder_id         = local.folder_id
        policy_for        = local.policy_for
        policy_type       = "list"
        allow             = ["ALLOW_INTERNAL_ONLY"]
        allow_list_length = 1
        constraint        = "constraints/cloudfunctions.allowedIngressSettings"
      }

      module "cloudfunction_vpc_connector_egress_settings" {
        source  = "terraform-google-modules/org-policy/google"
        version = "~> 5.1"

        organization_id   = local.organization_id
        folder_id         = local.folder_id
        policy_for        = local.policy_for
        policy_type       = "list"
        allow             = ["ALL_TRAFFIC"]
        allow_list_length = 1
        constraint        = "constraints/cloudfunctions.allowedVpcConnectorEgressSettings"
      }

      module "cloudrun_allowed_ingress" {
        source  = "terraform-google-modules/org-policy/google"
        version = "~> 5.1"

        organization_id   = local.organization_id
        folder_id         = local.folder_id
        policy_for        = local.policy_for
        policy_type       = "list"
        allow             = ["is:internal-and-cloud-load-balancing"]
        allow_list_length = 1
        constraint        = "constraints/run.allowedIngress"
      }

      module "cloudrun_allowed_vpc_egress" {
        source  = "terraform-google-modules/org-policy/google"
        version = "~> 5.1"

        organization_id   = local.organization_id
        folder_id         = local.folder_id
        policy_for        = local.policy_for
        policy_type       = "list"
        allow             = ["all-traffic"]
        allow_list_length = 1
        constraint        = "constraints/run.allowedVPCEgress"
      }
      ```

1. Push the code to your repository `gcp-org` in the `production` branch.

### 3-networks: Include environment step terraform service account in the restricted perimeter in network step

Environment step terraform service account needs to be added to the restricted VPC-SC perimeter because in the following step
you will enable an additional API in the restricted shared VPC project.

1. Update file [modules/base_env/main.tf](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/3-networks-dual-svpc/modules/base_env/main.tf#L213) in the `production` branch adding the Environment step terraform service account to the perimeter by updating the value for the variable `members` in the `restricted_shared_vpc` module:

    ```hcl
      members = distinct(concat([
        "serviceAccount:${local.networks_service_account}",
        "serviceAccount:${local.projects_service_account}",
        "serviceAccount:${local.organization_service_account}",
        "serviceAccount:${data.terraform_remote_state.bootstrap.outputs.environment_step_terraform_service_account_email}",
      ], var.perimeter_additional_members))
    ```

1. Commit changes in the `gcp-networks` repository and push the code to the `production` branch.

### 2-environments: Enable additional APIs and conditionally grant project IAM Admin role to the networks step terraform service account

1. Wait for the `gcp-networks` build from the previous step to finish.
1. Add the `"vpcaccess.googleapis.com"`, ` "certificatemanager.googleapis.com"`, `"networkservices.googleapis.com"`, and `"networksecurity.googleapis.com"` APIs on the `activate_apis` list in `restricted_shared_vpc_host_project` module in file [modules/env_baseline/networking.tf](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/2-environments/modules/env_baseline/networking.tf#LL68C1-L77C4)

    ```hcl
    activate_apis = [
        "compute.googleapis.com",
        "dns.googleapis.com",
        "servicenetworking.googleapis.com",
        "container.googleapis.com",
        "logging.googleapis.com",
        "cloudresourcemanager.googleapis.com",
        "accesscontextmanager.googleapis.com",
        "billingbudgets.googleapis.com",
        "vpcaccess.googleapis.com",
        "certificatemanager.googleapis.com",
        "networkservices.googleapis.com",
        "networksecurity.googleapis.com",
    ]
    ```

1. Conditionally grant to the networks step terraform service account the project IAM Admin and Certificate Manager Owner roles in the restricted shared project.
This is necessary for the configuration of the [Serverless VPC Access connector](https://cloud.google.com/vpc/docs/configure-serverless-vpc-access) and the [Secure Web Proxy](https://cloud.google.com/secure-web-proxy/docs/overview).
This role is granted here and not in the bootstrap step to limit the scope of this role effect.


1. Update file `gcp-environments/modules/env_baseline/variables.tf` to create a toggle for the deploy of the Secure Serverless Cloud Functions.

    ```hcl
    variable "enable_scf" {
      description = "Set to true to create the infrastructure needed by the Secure Cloud Function."
      type        = bool
      default     = false
    }
    ```

1. Update file `gcp-environments/envs/production/main.tf` to set the toggle to `true`:

    ```hcl
    module "env" {
      source = "../../modules/env_baseline"

      env                        = "production"
      environment_code           = "p"
      monitoring_workspace_users = var.monitoring_workspace_users
      remote_state_bucket        = var.remote_state_bucket

      enable_scf = true
      ...
    }
    ```

1. Update file `gcp-environments/modules/env_baseline/iam.tf` and add the conditional grant of the roles:

    ```hcl
    resource "google_project_iam_member" "iam_admin" {
      count = var.enable_scf ? 1 : 0

      project = module.restricted_shared_vpc_host_project.project_id
      role    = "roles/resourcemanager.projectIamAdmin"
      member  = "serviceAccount:${data.terraform_remote_state.bootstrap.outputs.networks_step_terraform_service_account_email}"
    }

    resource "google_project_iam_member" "certificate_manager_owner" {
      count = var.enable_scf ? 1 : 0

      project = module.restricted_shared_vpc_host_project.project_id
      role    = "roles/certificatemanager.owner"
      member  = "serviceAccount:${data.terraform_remote_state.bootstrap.outputs.networks_step_terraform_service_account_email}"
    }
    ```

1. Push the code for the `production` branch in the repository `gcp-environment`.

### 4-projects: Create a new workspace for the Secure Cloud Function

Create a new workspace in the business unit 1 shared environment to isolate the resources that
will deployed in the Secure Cloud Function that will be created in step `5-app-infra`.

1. Update file [business_unit_1/shared/example_infra_pipeline.tf](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/4-projects/business_unit_1/shared/example_infra_pipeline.tf#L18) to add a new repository in the locals:

    ```hcl
    locals {
      repo_names = ["bu1-example-app", "bu1-scf-app"]
    }
    ```

1. Add the `"bigquery.googleapis.com"` and `"serviceusage.googleapis.com"` APIs to the list of [activate_apis](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/4-projects/business_unit_1/shared/example_infra_pipeline.tf#L31) in the `app_infra_cloudbuild_project` module:

    ```hcl
      activate_apis = [
        "cloudbuild.googleapis.com",
        "sourcerepo.googleapis.com",
        "cloudkms.googleapis.com",
        "iam.googleapis.com",
        "artifactregistry.googleapis.com",
        "cloudresourcemanager.googleapis.com",
        "bigquery.googleapis.com",
        "serviceusage.googleapis.com",
      ]
    ```

1. Wait for the `gcp-environments` build from the previous step to finish.
1. Commit changes in the `gcp-projects` repository and push the code to the `production` branch.

### 4-projects: Create Serverless project, security project, and additional harness in the production environment

1. Update file `gcp-projects/modules/base_env/variables.tf` to create a toggle for the deploy of the Secure Cloud Function:

    ```hcl
    variable "enable_scf" {
      description = "Set to true to create the infrastructure needed by the Secure Cloud Function."
      type        = bool
      default     = false
    }
    ```

1. Update file `gcp-projects/modules/base_env/outputs.tf` to add the outputs related to the new projects:

    ```hcl
        output "serverless_project_id" {
          description = "The ID of the project in which Secure Cloud Functions serverless resources will be created."
          value       = var.enable_scf ? module.serverless_project[0].project_id : ""
        }

        output "serverless_project_number" {
          description = "The project number in which Secure Cloud Functions serverless resources will be created."
          value       = var.enable_scf ? module.serverless_project[0].project_number : ""
        }

        output "security_project_id" {
          description = "The ID of the project in which Secure Cloud Functions security resources will be created."
          value       = var.enable_scf ? module.security_project[0].project_id : ""
        }

        output "cloudfunction_source_bucket_name" {
          description = "Cloud Function Source Bucket."
          value       = var.enable_scf ? module.cloudfunction_source_bucket[0].bucket.name : ""
        }

        output "serverless_service_account_email" {
          description = "The service account created in the serverless project."
          value       = var.enable_scf ? module.service_accounts[0].email : ""
        }

        output "default_region" {
          description = "Default region to create resources where applicable."
          value       = local.default_region
        }

        output "serverless_project_cb_sa" {
          description = "The Cloud Build service account created for the serverless project."
          value       = var.enable_scf ? google_project_service_identity.cloudbuild_sa[0].email : ""
        }

        output "serverless_project_gcs_sa" {
          description = "The Google Cloud Storage service account created for the serverless project."
          value       = var.enable_scf ? data.google_storage_project_service_account.serverless_project_gcs_account[0].email_address : ""
        }
    ```

1. Update file `gcp-projects/business_unit_1/production/outputs.tf` to add the outputs related to the new projects:

    ```hcl
        output "serverless_project_id" {
          description = "The ID of the project in which Secure Cloud Functions serverless resources will be created."
          value       = module.env.serverless_project_id
        }

        output "serverless_project_number" {
          description = "The project number in which Secure Cloud Functions serverless resources will be created."
          value       = module.env.serverless_project_number
        }

        output "security_project_id" {
          description = "The ID of the project in which Secure Cloud Functions security resources will be created."
          value       = module.env.security_project_id
        }

        output "cloudfunction_source_bucket_name" {
          description = "Cloud Function Source Bucket."
          value       = module.env.cloudfunction_source_bucket_name
        }

        output "serverless_service_account_email" {
          description = "The service account created in the serverless project."
          value       = module.env.serverless_service_account_email
        }

        output "default_region" {
          description = "Default region to create resources where applicable."
          value       = module.env.default_region
        }

        output "serverless_project_cb_sa" {
          description = "The Cloud Build service account created for the serverless project."
          value       = module.env.serverless_project_cb_sa
        }

        output "serverless_project_gcs_sa" {
          description = "The Google Cloud Storage service account created for the serverless project."
          value       = module.env.serverless_project_gcs_sa
        }
    ```

1. Create file `example_secure_cloud_function_projects.tf` in folder `gcp-projects/modules/base_env` and copy the following code

    ```hcl
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

    locals {
      eventarc_identities     = var.enable_scf ? ["serviceAccount:${google_project_service_identity.eventarc_sa[0].email}"] : []
      gcs_identities          = var.enable_scf ? ["serviceAccount:${data.google_storage_project_service_account.serverless_project_gcs_account[0].email_address}"] : []
      decrypters              = var.enable_scf ? join(",", concat(["serviceAccount:${google_project_service_identity.artifact_sa[0].email}"], local.eventarc_identities, local.gcs_identities)) : ""
      encrypters              = var.enable_scf ? join(",", concat(["serviceAccount:${google_project_service_identity.artifact_sa[0].email}"], local.eventarc_identities, local.gcs_identities)) : ""
      serverless_key_name     = "key-secure-artifact-registry"
      serverless_keyring_name = "krg-secure-artifact-registry"
      default_region          = data.terraform_remote_state.bootstrap.outputs.common_config.default_region

    }

    module "serverless_project" {
      source = "../single_project"
      count  = var.enable_scf ? 1 : 0

      org_id                     = local.org_id
      billing_account            = local.billing_account
      folder_id                  = local.env_folder_name
      environment                = var.env
      vpc_type                   = "restricted"
      shared_vpc_host_project_id = local.restricted_host_project_id
      shared_vpc_subnets         = local.restricted_subnets_self_links
      project_budget             = var.project_budget
      project_prefix             = local.project_prefix

      enable_cloudbuild_deploy            = local.enable_cloudbuild_deploy
      app_infra_pipeline_service_accounts = local.app_infra_pipeline_service_accounts

      sa_roles = {
        "${var.business_code}-scf-app" = [
          "roles/artifactregistry.admin",
          "roles/bigquery.admin",
          "roles/bigquery.jobUser",
          "roles/cloudbuild.builds.editor",
          "roles/cloudbuild.workerPoolOwner",
          "roles/cloudfunctions.admin",
          "roles/iam.serviceAccountAdmin",
          "roles/iam.serviceAccountUser",
          "roles/serviceusage.serviceUsageAdmin",
          "roles/storage.admin",
          "roles/resourcemanager.projectIamAdmin",
          "roles/pubsub.admin",
        ]
      }

      activate_apis = [
        "accesscontextmanager.googleapis.com",
        "vpcaccess.googleapis.com",
        "container.googleapis.com",
        "run.googleapis.com",
        "eventarc.googleapis.com",
        "cloudbuild.googleapis.com",
        "cloudfunctions.googleapis.com",
        "cloudresourcemanager.googleapis.com",
        "storage-api.googleapis.com",
        "serviceusage.googleapis.com",
        "servicenetworking.googleapis.com",
        "iam.googleapis.com",
        "dns.googleapis.com",
        "pubsub.googleapis.com",
        "bigquery.googleapis.com",
        "cloudbilling.googleapis.com",
        "cloudkms.googleapis.com",
        "cloudbuild.googleapis.com",
        "artifactregistry.googleapis.com",
        "compute.googleapis.com",
        "networksecurity.googleapis.com",
      ]

      vpc_service_control_attach_enabled = "true"
      vpc_service_control_perimeter_name = "accessPolicies/${local.access_context_manager_policy_id}/servicePerimeters/${local.perimeter_name}"
      vpc_service_control_sleep_duration = "60s"

      # Metadata
      project_suffix    = "c-func"
      application_name  = "${var.business_code}-c-func"
      billing_code      = "1234"
      primary_contact   = "example@example.com"
      secondary_contact = "example2@example.com"
      business_code     = var.business_code
    }

    resource "google_project_iam_member" "vpcaccess_admin" {
      count = var.enable_scf ? 1 : 0

      project = module.serverless_project[0].project_id
      role    = "roles/vpcaccess.admin"
      member  = "serviceAccount:${data.terraform_remote_state.bootstrap.outputs.networks_step_terraform_service_account_email}"
    }

    module "security_project" {
      source = "../single_project"
      count  = var.enable_scf ? 1 : 0

      org_id                     = local.org_id
      billing_account            = local.billing_account
      folder_id                  = local.env_folder_name
      environment                = var.env
      vpc_type                   = "restricted"
      shared_vpc_host_project_id = local.restricted_host_project_id
      shared_vpc_subnets         = local.restricted_subnets_self_links
      project_budget             = var.project_budget
      project_prefix             = local.project_prefix

      enable_cloudbuild_deploy            = local.enable_cloudbuild_deploy
      app_infra_pipeline_service_accounts = local.app_infra_pipeline_service_accounts

      sa_roles = {
        "${var.business_code}-scf-app" = [
          "roles/storage.admin",
          "roles/bigquery.admin",
          "roles/serviceusage.serviceUsageAdmin",
          "roles/cloudkms.admin",
        ]
      }

      activate_apis = [
        "cloudbilling.googleapis.com",
        "cloudkms.googleapis.com",
        "artifactregistry.googleapis.com",
        "compute.googleapis.com",
      ]

      vpc_service_control_attach_enabled = "true"
      vpc_service_control_perimeter_name = "accessPolicies/${local.access_context_manager_policy_id}/servicePerimeters/${local.perimeter_name}"
      vpc_service_control_sleep_duration = "60s"

      # Metadata
      project_suffix    = "sec"
      application_name  = "${var.business_code}-sec"
      billing_code      = "1234"
      primary_contact   = "example@example.com"
      secondary_contact = "example2@example.com"
      business_code     = var.business_code
    }

    module "service_accounts" {
      source  = "terraform-google-modules/service-accounts/google"
      version = "~> 4.2"
      count   = var.enable_scf ? 1 : 0

      project_id = module.serverless_project[0].project_id
      prefix     = "sa"
      names      = ["cloud-function"]

      depends_on = [
        module.serverless_project
      ]
    }

    resource "google_project_iam_member" "cloud_run_sa_roles" {
      for_each = var.enable_scf ? toset(["roles/eventarc.eventReceiver", "roles/viewer", "roles/compute.networkViewer", "roles/run.invoker"]) : []

      project = module.serverless_project[0].project_id
      role    = each.value
      member  = module.service_accounts[0].iam_email
    }

    resource "google_project_service_identity" "serverless_sa" {
      provider = google-beta
      count    = var.enable_scf ? 1 : 0

      project = module.serverless_project[0].project_id
      service = "cloudfunctions.googleapis.com"
    }

    resource "google_service_account_iam_member" "identity_service_account_user" {
      count = var.enable_scf ? 1 : 0

      service_account_id = module.service_accounts[0].service_account.id
      role               = "roles/iam.serviceAccountUser"
      member             = "serviceAccount:${google_project_service_identity.serverless_sa[0].email}"
    }

    resource "google_project_service_identity" "cloudbuild_sa" {
      provider = google-beta
      count    = var.enable_scf ? 1 : 0

      project = module.serverless_project[0].project_id
      service = "cloudbuild.googleapis.com"
    }

    resource "google_project_service_identity" "eventarc_sa" {
      provider = google-beta
      count    = var.enable_scf ? 1 : 0

      project = module.serverless_project[0].project_id
      service = "eventarc.googleapis.com"
    }

    data "google_storage_project_service_account" "serverless_project_gcs_account" {
      count = var.enable_scf ? 1 : 0

      project = module.serverless_project[0].project_id
    }

    resource "google_project_iam_member" "gcs_pubsub_publishing" {
      count = var.enable_scf ? 1 : 0

      project = module.serverless_project[0].project_id
      role    = "roles/pubsub.publisher"
      member  = "serviceAccount:${data.google_storage_project_service_account.serverless_project_gcs_account[0].email_address}"
    }

    resource "google_project_iam_member" "eventarc_service_agent" {
      count = var.enable_scf ? 1 : 0

      project = module.serverless_project[0].project_id
      role    = "roles/eventarc.serviceAgent"
      member  = "serviceAccount:${google_project_service_identity.eventarc_sa[0].email}"
    }

    resource "google_artifact_registry_repository" "repo" {
      count = var.enable_scf ? 1 : 0

      project       = module.security_project[0].project_id
      location      = local.default_region
      repository_id = "rep-secure-cloud-function"
      description   = "Secure Cloud Run Artifact Registry Repository"
      format        = "DOCKER"
      kms_key_name  = module.artifact_registry_kms[0].keys[local.serverless_key_name]
    }

    resource "google_artifact_registry_repository_iam_member" "member" {
      count = var.enable_scf ? 1 : 0

      project    = module.security_project[0].project_id
      location   = local.default_region
      repository = google_artifact_registry_repository.repo[0].repository_id
      role       = "roles/artifactregistry.reader"
      member     = "serviceAccount:${google_project_service_identity.serverless_sa[0].email}"
    }

    resource "time_sleep" "sa_propagation" {
      create_duration = "60s"

      depends_on = [
        google_project_service_identity.artifact_sa,
        google_project_service_identity.eventarc_sa,
        data.google_storage_project_service_account.serverless_project_gcs_account,
      ]
    }

    module "artifact_registry_kms" {
      source  = "terraform-google-modules/kms/google"
      version = "~> 2.2"
      count   = var.enable_scf ? 1 : 0

      project_id           = module.security_project[0].project_id
      location             = local.default_region
      keyring              = local.serverless_keyring_name
      keys                 = [local.serverless_key_name]
      set_decrypters_for   = [local.serverless_key_name]
      set_encrypters_for   = [local.serverless_key_name]
      decrypters           = [local.decrypters]
      encrypters           = [local.encrypters]
      prevent_destroy      = false
      key_rotation_period  = var.key_rotation_period
      key_protection_level = "HSM"

      depends_on = [
        time_sleep.sa_propagation
      ]
    }

    resource "google_project_service_identity" "artifact_sa" {
      provider = google-beta
      count    = var.enable_scf ? 1 : 0

      project = module.security_project[0].project_id
      service = "artifactregistry.googleapis.com"
    }

    module "cloudfunction_source_bucket" {
      source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
      version = "~>3.4"
      count   = var.enable_scf ? 1 : 0

      project_id    = module.serverless_project[0].project_id
      name          = "bkt-${local.default_region}-${module.serverless_project[0].project_number}-cfv2-zip-files"
      location      = local.default_region
      storage_class = "REGIONAL"
      force_destroy = true

      encryption = {
        default_kms_key_name = module.artifact_registry_kms[0].keys[local.serverless_key_name]
      }

      depends_on = [
        module.artifact_registry_kms
      ]
    }
    ```

1. Update file `gcp-projects/business_unit_1/production/main.tf` to set the toggle to `true`:

    ```hcl
    module "env" {
      source = "../../modules/base_env"

      env                       = "production"
      business_code             = "bu1"
      business_unit             = "business_unit_1"
      remote_state_bucket       = var.remote_state_bucket
      location_kms              = var.location_kms
      location_gcs              = var.location_gcs
      peering_module_depends_on = var.peering_module_depends_on

      enable_scf = true
    }
    ```

1. Wait for the `gcp-projects` build from the previous step to finish.
1. Commit changes in the `gcp-projects` repository and push the code to the `production` branch.

### 3-networks: Deploy the serverless connector, the Secure Web Proxy, and add new workspace service account, GCS service account, and Cloud build service account to the restricted perimeter

1. Get the new workspace service account to the restricted perimeter:

    ```bash
    terraform -chdir="gcp-projects/business_unit_1/shared" init
    export app_infra_sa=$(terraform -chdir="gcp-projects/business_unit_1/shared" output -json terraform_service_accounts | jq '."bu1-scf-app"' --raw-output)
    echo "APP_INFRA_SA_EMAIL = ${app_infra_sa}"
    ```

1. Get the serverless project id:

    ```bash
    terraform -chdir="gcp-projects/business_unit_1/production" init
    export SERVERLESS_PROJECT_ID=$(terraform -chdir="gcp-projects/business_unit_1/production" output -raw serverless_project_id)
    echo "SERVERLESS_PROJECT_ID = ${SERVERLESS_PROJECT_ID}"
    ```

1. Get the serverless GCS service account:

    ```bash
    export SERVERLESS_PROJECT_GCS_SA=$(terraform -chdir="gcp-projects/business_unit_1/production" output -raw serverless_project_gcs_sa)
    echo "SERVERLESS_PROJECT_GCS_SA = ${SERVERLESS_PROJECT_GCS_SA}"
    ```

1. Get the serverless Cloud Build service account:

    ```bash
    export SERVERLESS_PROJECT_CB_SA=$(terraform -chdir="gcp-projects/business_unit_1/production" output -raw serverless_project_cb_sa)
    echo "SERVERLESS_PROJECT_CB_SA = ${SERVERLESS_PROJECT_CB_SA}"
    ```


1. Update file `gcp-networks/envs/production/main.tf` replace the value for the variable `perimeter_additional_members` adding the three new Service Account: APP_INFRA_SA_EMAIL, SERVERLESS_PROJECT_GCS_SA, and  SERVERLESS_PROJECT_CB_SA. Replace their place holders with the values from the outputs of the commands from the previous steps:

    ```hcl
    perimeter_additional_members = concat(var.perimeter_additional_members, [
    "serviceAccount:APP_INFRA_SA_EMAIL",
    "serviceAccount:SERVERLESS_PROJECT_GCS_SA",
    "serviceAccount:SERVERLESS_PROJECT_CB_SA",
    ])
    ```

1. Update file `gcp-networks/envs/production/main.tf` to include a new **local** `restricted_subnet_web_proxy_ip`:

    ```hcl

    restricted_subnet_secure_web_proxy_ip = {
      (local.default_region1) = "10.8.192.10"
      (local.default_region2) = "10.9.192.10"
    }

    ```

1. Update file `gcp-networks/modules/base_env/variables.tf` to create a toggle for the deploy of the Secured Cloud Function and the Secure Web Proxy IPs:

    ```hcl
    variable "enable_scf" {
      description = "Set to true to create the infrastructure needed by the Secure Cloud Function."
      type        = bool
      default     = false
    }

    variable "restricted_subnet_secure_web_proxy_ip" {
     description = "The IPs the will be used by the Secure Web Proxy instance."
     type        = map(string)
     default     = {}
    }
    ```

1. Update file `gcp-networks/modules/base_env/outputs.tf` to add the `restricted_serverless_network_connector_id` output:

    ```hcl
    output "restricted_serverless_network_connector_id" {
      description = "VPC serverless connector ID for the restricted network."
      value       = var.enable_scf ? module.serverless_connector[0].connector_id : ""
    }
    ```

1. Update file `gcp-networks/envs/production/outputs.tf` to add the `restricted_serverless_network_connector_id` and the `restricted_subnet_secure_web_proxy_ip` outputs:

    ```hcl
    output "restricted_serverless_network_connector_id" {
      description = "VPC serverless connector ID for the restricted network."
      value       = module.base_env.restricted_serverless_network_connector_id
    }

    output "restricted_subnet_secure_web_proxy_ip" {
      description = "The IPs the will be used by the Secure Web Proxy instance."
      value       = local.restricted_subnet_secure_web_proxy_ip
    }
    ```

1. Update file `gcp-networks/envs/production/main.tf` to set the toggle to `true` and set the `restricted_subnet_secure_web_proxy_ip`:

    ```hcl
    module "base_env" {
      source = "../../modules/base_env"

      env                                   = local.env
      environment_code                      = local.environment_code
      access_context_manager_policy_id      = var.access_context_manager_policy_id

    ...

      enable_scf = true

      restricted_subnet_secure_web_proxy_ip = local.restricted_subnet_secure_web_proxy_ip
    }
    ```

1. Create file `gcp-networks/modules/base_env/scf_serverless_connector.tf` and copy the following content:

    ```hcl
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

    locals {
      default_region = data.terraform_remote_state.bootstrap.outputs.common_config.default_region
      // serverless project info
      serverless_project_id = "SERVERLESS_PROJECT_ID"
    }

    resource "google_project_service_identity" "serverless_sa" {
      provider = google-beta
      count    = var.enable_scf ? 1 : 0

      project = local.serverless_project_id
      service = "cloudfunctions.googleapis.com"
    }

    module "serverless_connector" {
      source  = "GoogleCloudPlatform/cloud-run/google//modules/secure-serverless-net"
      version = "~> 0.9"
      count   = var.enable_scf ? 1 : 0

      connector_name            = "serverless-connector"
      subnet_name               = "sb-p-connector-${local.default_region}"
      location                  = local.default_region
      vpc_project_id            = local.restricted_project_id
      serverless_project_id     = local.serverless_project_id
      shared_vpc_name           = module.restricted_shared_vpc.network_name
      ip_cidr_range             = "10.4.0.0/28"
      resource_names_suffix     = "scf"
      create_subnet             = true
      connector_on_host_project = false
      enable_load_balancer_fw   = false

      serverless_service_identity_email = google_project_service_identity.serverless_sa[0].email
    }
    ```

1. Replace `SERVERLESS_PROJECT_ID` with the `SERVERLESS_PROJECT_ID` from the previous step
1. Update the `target_tags` property in the file [restricted_shared_vpc/firewall.tf](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/3-networks-dual-svpc/modules/restricted_shared_vpc/firewall.tf#LL69C1-L69C38) adding the tag `"vpc-connector"` to the firewall rule that allows Google private API access.

    ```hcl
    target_tags = ["allow-google-apis", "vpc-connector"]
    ```

1. Fix the Rule [priority](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/3-networks-dual-svpc/modules/restricted_shared_vpc/firewall.tf#LL50C1-L50C20) to be `65430`

    ```hcl
    priority  = 65430
    ```

1. Create file `gcp-networks/modules/base_env/scf_secure_web_proxy.tf` and copy the following content:

    ```hcl
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

    resource "null_resource" "generate_certificate" {
      count = var.enable_scf ? 1 : 0

      triggers = {
        project_id = local.restricted_project_id
        region     = local.default_region
      }

      provisioner "local-exec" {
        when    = create
        command = <<EOT
          ${path.module}/generate_swp_certificate.sh \
            ${local.restricted_project_id} \
            ${local.default_region}
        EOT
      }

      provisioner "local-exec" {
        when    = destroy
        command = <<EOT
          gcloud certificate-manager certificates delete swp-certificate \
            --location=${self.triggers.region} --project=${self.triggers.project_id} \
            --quiet
        EOT
      }
    }

    resource "time_sleep" "wait_upload_certificate" {
      count = var.enable_scf ? 1 : 0

      create_duration  = "1m"
      destroy_duration = "3m"

      depends_on = [
        null_resource.generate_certificate
      ]
    }

    module "secure_web_proxy" {
      source  = "GoogleCloudPlatform/cloud-functions/google//modules/secure-web-proxy"
      count   = var.enable_scf ? 1 : 0
      version = "~> 0.6.0"

      project_id          = local.restricted_project_id
      region              = local.default_region
      network_id          = "projects/${local.restricted_project_id}/global/networks/${module.restricted_shared_vpc.network_name}"
      subnetwork_id       = "projects/${local.restricted_project_id}/regions/${local.default_region}/subnetworks/sb-${var.environment_code}-shared-restricted-${local.default_region}"
      subnetwork_ip_range = var.restricted_subnet_primary_ranges[local.default_region]
      certificates        = ["projects/${local.restricted_project_id}/locations/${local.default_region}/certificates/swp-certificate"]
      addresses           = [var.restricted_subnet_secure_web_proxy_ip[local.default_region]]
      ports               = [443]
      proxy_ip_range      = "10.129.0.0/23"

      # This list of URL was obtained through Cloud Function imports
      # It will change depending on what imports your CF are using.
      url_lists = [
        "*google.com/go*",
        "*github.com/GoogleCloudPlatform*",
        "*github.com/cloudevents*",
        "*golang.org/x*",
        "*google.golang.org/*",
        "*github.com/golang/*",
        "*github.com/google/*",
        "*github.com/googleapis/*",
        "*github.com/json-iterator/go",
        "*github.com/modern-go/concurrent",
        "*github.com/modern-go/reflect2",
        "*go.opencensus.io",
        "*go.uber.org/atomic",
        "*go.uber.org/multierr",
        "*go.uber.org/zap"
      ]

      depends_on = [
        null_resource.generate_certificate,
        time_sleep.wait_upload_certificate
      ]
    }
    ```

1. Create file `gcp-networks/modules/base_env/generate_swp_certificate.sh` and copy the following content:

    ```bash
    #!/bin/bash

    # Copyright 2023 Google LLC
    #
    # Licensed under the Apache License, Version 2.0 (the "License");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    #
    #      http://www.apache.org/licenses/LICENSE-2.0
    #
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an "AS IS" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.

    project_id=${1}
    location=${2}

    generate_self_signed_certificate() {
        if [[ ! -x "$(command -v openssl)" ]]; then
            echo "openssl not found"
            exit 1
        fi

        openssl req -x509 -newkey rsa:2048 \
            -keyout key.pem \
            -out cert.pem -days 365 \
            -subj '/CN=myswp.example.com' -nodes \
            -addext "subjectAltName=DNS:myswp.example.com"

        gcloud certificate-manager certificates create swp-certificate \
            --certificate-file=cert.pem \
            --private-key-file=key.pem \
            --location="${location}" \
            --project="${project_id}"
    }
    generate_self_signed_certificate
    ```

1. Ensure that the file `generate_swp_certificate.sh` has the execute permission

    ```bash
    chmod 755 gcp-networks/modules/base_env/generate_swp_certificate.sh
    ```

1. Commit changes in the `gcp-networks` repository and push the code to the `production` branch.

### 4-projects: include additional restricted outputs in the production environment

This is required because the build in stage `5-app-infra` only has access to the remote state of the `4-projects` stage.

1. Update file `gcp-projects/modules/base_env/outputs.tf` to add the outputs:

    ```hcl
        output "restricted_host_project_id" {
          description = "Restricted host project id."
          value       = local.restricted_host_project_id
        }

        output "restricted_network_name" {
          description = "Restricted network name."
          value       = local.restricted_network_name
        }

        output "restricted_serverless_network_connector_id" {
          description = "VPC serverless connector ID for the restricted network."
          value       = local.restricted_serverless_network_connector_id
        }

        output "restricted_subnet_secure_web_proxy_ip" {
          description = "The IPs the will be used by the Secure Web Proxy instance."
          value       = local.restricted_subnet_secure_web_proxy_ip
        }
    ```

1. Update file `gcp-projects/business_unit_1/production/outputs.tf` to add the outputs:

    ```hcl
        output "restricted_host_project_id" {
          description = "Restricted host project id."
          value       = module.env.restricted_host_project_id
        }

        output "restricted_network_name" {
          description = "Restricted network name."
          value       = module.env.restricted_network_name
        }

        output "restricted_serverless_network_connector_id" {
          description = "VPC serverless connector ID for the restricted network."
          value       = module.env.restricted_serverless_network_connector_id
        }

        output "restricted_subnet_secure_web_proxy_ip" {
          description = "The IPs the will be used by the Secure Web Proxy instance."
          value       = module.env.restricted_subnet_secure_web_proxy_ip
        }
    ```

1. Update file `gcp-projects/modules/base_env/example_secure_cloud_function_projects.tf` to add the new locals:

    ```hcl
    restricted_network_name                    = data.terraform_remote_state.network_env.outputs.restricted_network_name
    restricted_serverless_network_connector_id = try(data.terraform_remote_state.network_env.outputs.restricted_serverless_network_connector_id, "")
    restricted_subnet_secure_web_proxy_ip      = try(data.terraform_remote_state.network_env.outputs.restricted_subnet_secure_web_proxy_ip, {})
    ```

1. Commit changes in the `gcp-projects` repository and push the code to the `production` branch.

### 5-app-infra: Deploy the Secure Cloud Function with Bigquery and Eventarc

1. Go to the builds page of the **App Infra** project in Google Cloud Console to follow the build execution of the next steps:

    ```bash
    export DEFAULT_REGION=$(terraform -chdir="gcp-bootstrap/envs/shared" output -json common_config | jq '.default_region' --raw-output)
    echo ${DEFAULT_REGION}

    export INFRA_PIPELINE_PROJECT_ID=$(terraform -chdir="gcp-projects/business_unit_1/shared/" output -raw cloudbuild_project_id)
    echo ${INFRA_PIPELINE_PROJECT_ID}

    echo "builds page = https://console.cloud.google.com/cloud-build/builds;region=${DEFAULT_REGION}?project=${INFRA_PIPELINE_PROJECT_ID}"
    ```

1. Clone the new repo created in step 4-projects/shared:

    ```bash
    gcloud source repos clone bu1-scf-app --project=${INFRA_PIPELINE_PROJECT_ID}
    ```

1. Create the required files and copy basic files from the foundation repo.
We consider that the `terraform-example-foundation` directory is at the same level of the `bu1-scf-app` directory.

    ```bash
      cd bu1-scf-app
      git checkout -b plan

      mkdir -p  business_unit_1/production/functions/bq-to-cf
      mkdir -p  business_unit_1/production/templates
      touch business_unit_1/production/backend.tf
      touch business_unit_1/production/versions.tf
      touch business_unit_1/production/variables.tf
      touch business_unit_1/production/terraform.tfvars
      touch business_unit_1/production/main.tf

      cp ../terraform-example-foundation/build/cloudbuild-tf-* .
      cp ../terraform-example-foundation/build/tf-wrapper.sh .
      cp ../terraform-example-foundation/5-app-infra/.gitignore .
      chmod 755 ./tf-wrapper.sh
    ```

1. Edit file `bu1-scf-app/business_unit_1/production/backend.tf` adding the following code

    ```hcl
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

    terraform {
      backend "gcs" {
        bucket = "UPDATE_APP_INFRA_SCF_BUCKET"
        prefix = "terraform/scf/business_unit_1/production"
      }
    }
    ```

1. Edit file `bu1-scf-app/business_unit_1/production/versions.tf` adding the following code

    ```hcl
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

    terraform {
      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "< 7.0"
        }
        google-beta = {
          source  = "hashicorp/google-beta"
          version = "< 7.0"
        }
      }
      required_version = ">= 0.13"
    }
    ```

1. Edit file `bu1-scf-app/business_unit_1/production/variables.tf` adding the following code

    ```hcl
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

    variable "remote_state_bucket" {
      description = "Backend bucket to load remote state information from previous steps."
      type        = string
    }
    ```

1. Edit file `bu1-scf-app/business_unit_1/production/terraform.tfvars` adding the following code

    ```hcl
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

    remote_state_bucket = "REMOTE_STATE_BUCKET"
    ```

1. Update terraform backend and remote state configuration:

    ```bash
    backend_bucket=$(terraform -chdir="../gcp-projects/business_unit_1/shared" output -json state_buckets | jq '."bu1-scf-app"' --raw-output)
    echo "backend_bucket = ${backend_bucket}"

    sed -i "s/UPDATE_APP_INFRA_SCF_BUCKET/${backend_bucket}/" ./business_unit_1/production/backend.tf

    export remote_state_bucket=$(terraform -chdir="../gcp-bootstrap/envs/shared" output -raw projects_gcs_bucket_tfstate)
    echo "remote_state_bucket = ${remote_state_bucket}"

    sed -i "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" ./business_unit_1/production/terraform.tfvars
    ```

1. Copy Cloud Function code and BigQuery template from the `terraform-google-cloud-functions` repo
We consider that the `terraform-google-cloud-functions` directory is at the same level of the `bu1-scf-app` directory.

    ```bash
    SCF_PATH="../terraform-google-cloud-functions/examples/secure_cloud_function_bigquery_trigger"
    cp "${SCF_PATH}/templates/bigquery_schema.template" ./business_unit_1/production/templates/bigquery_schema.template
    cp "${SCF_PATH}/functions/bq-to-cf/go.mod" ./business_unit_1/production/functions/bq-to-cf/go.mod
    cp "${SCF_PATH}/functions/bq-to-cf/main.go" ./business_unit_1/production/functions/bq-to-cf/main.go
    ```

1. Edit file `bu1-scf-app/business_unit_1/production/main.tf` adding the following code

    ```hcl
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

    locals {
      location                                   = data.terraform_remote_state.projects_env.outputs.default_region
      serverless_project_id                      = data.terraform_remote_state.projects_env.outputs.serverless_project_id
      serverless_project_number                  = data.terraform_remote_state.projects_env.outputs.serverless_project_number
      security_project_id                        = data.terraform_remote_state.projects_env.outputs.security_project_id
      restricted_host_project_id                 = data.terraform_remote_state.projects_env.outputs.restricted_host_project_id
      restricted_network_name                    = data.terraform_remote_state.projects_env.outputs.restricted_network_name
      cloudfunction_source_bucket_name           = data.terraform_remote_state.projects_env.outputs.cloudfunction_source_bucket_name
      restricted_serverless_network_connector_id = data.terraform_remote_state.projects_env.outputs.restricted_serverless_network_connector_id
      restricted_subnet_secure_web_proxy_ip      = data.terraform_remote_state.projects_env.outputs.restricted_subnet_secure_web_proxy_ip
      serverless_service_account_email           = data.terraform_remote_state.projects_env.outputs.serverless_service_account_email
      repository_name                            = "rep-secure-cloud-function"
      table_name                                 = "tbl_test"
      kms_bigquery                               = "key-secure-bigquery"
      key_name                                   = "key-secure-cloud-function"
      keyring_name                               = "krg-secure-cloud-function"

      encrypters = [
        "serviceAccount:${google_project_service_identity.cloudfunction_sa.email}",
        "serviceAccount:${local.serverless_service_account_email}",
        "serviceAccount:${google_project_service_identity.artifact_sa.email}",
        "serviceAccount:${google_project_service_identity.pubsub_sa.email}",
        "serviceAccount:${google_project_service_identity.eventarc_sa.email}",
        "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
      ]

      decrypters = [
        "serviceAccount:${google_project_service_identity.cloudfunction_sa.email}",
        "serviceAccount:${local.serverless_service_account_email}",
        "serviceAccount:${google_project_service_identity.artifact_sa.email}",
        "serviceAccount:${google_project_service_identity.pubsub_sa.email}",
        "serviceAccount:${google_project_service_identity.eventarc_sa.email}",
        "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
      ]
    }

    // remote state
    data "terraform_remote_state" "projects_env" {
      backend = "gcs"

      config = {
        bucket = var.remote_state_bucket
        prefix = "terraform/projects/business_unit_1/production"
      }
    }

    resource "random_id" "suffix" {
      byte_length = 2
    }

    data "archive_file" "cf_bigquery_source" {
      type        = "zip"
      source_dir  = "${path.module}/functions/bq-to-cf/"
      output_path = "functions/cloudfunction-bq-source-${random_id.suffix.hex}.zip"
    }

    resource "google_storage_bucket_object" "cf_bigquery_source_zip" {
      source       = data.archive_file.cf_bigquery_source.output_path
      content_type = "application/zip"

      # Append to the MD5 checksum of the files's content
      # to force the zip to be updated as soon as a change occurs
      name   = "src-${data.archive_file.cf_bigquery_source.output_md5}.zip"
      bucket = local.cloudfunction_source_bucket_name

      depends_on = [
        data.archive_file.cf_bigquery_source
      ]
    }

    data "google_bigquery_default_service_account" "bq_sa" {
      project = local.serverless_project_id
    }

    module "bigquery_kms" {
      source  = "terraform-google-modules/kms/google"
      version = "~> 2.2"

      project_id           = local.security_project_id
      location             = local.location
      keyring              = "krg-secure-bigquery"
      keys                 = [local.kms_bigquery]
      set_decrypters_for   = [local.kms_bigquery]
      set_encrypters_for   = [local.kms_bigquery]
      decrypters           = ["serviceAccount:${data.google_bigquery_default_service_account.bq_sa.email}"]
      encrypters           = ["serviceAccount:${data.google_bigquery_default_service_account.bq_sa.email}"]
      prevent_destroy      = false
      key_rotation_period  = "7776000s"
      key_protection_level = "HSM"
    }

    module "bigquery" {
      source  = "terraform-google-modules/bigquery/google"
      version = "~> 5.4"

      dataset_id                  = "dst_secure_cloud_function"
      dataset_name                = "dst-secure-cloud-function"
      description                 = "Dataset to trigger a secure Cloud Function"
      project_id                  = local.serverless_project_id
      location                    = local.location
      default_table_expiration_ms = 3600000
      encryption_key              = module.bigquery_kms.keys[local.kms_bigquery]

      tables = [
        {
          table_id          = local.table_name,
          schema            = file("${path.module}/templates/bigquery_schema.template")
          time_partitioning = null,
          range_partitioning = {
            field = "Card_PIN",
            range = {
              start    = "1"
              end      = "100",
              interval = "10",
            },
          },
          expiration_time = 2524604400000, # 2050/01/01
          clustering      = [],
          labels = {
            env      = "production"
            billable = "true"
          }
      }]
    }

    data "google_service_account" "cloud_serverless_sa" {
      account_id = local.serverless_service_account_email
    }

    resource "google_service_account_iam_member" "identity_service_account_user" {
      service_account_id = data.google_service_account.cloud_serverless_sa.name
      role               = "roles/iam.serviceAccountUser"
      member             = "serviceAccount:${google_project_service_identity.cloudfunction_sa.email}"
    }

    resource "google_project_service_identity" "eventarc_sa" {
      provider = google-beta

      project = local.serverless_project_id
      service = "eventarc.googleapis.com"
    }

    resource "google_project_service_identity" "cloudfunction_sa" {
      provider = google-beta

      project = local.serverless_project_id
      service = "cloudfunctions.googleapis.com"
    }

    resource "google_project_service_identity" "artifact_sa" {
      provider = google-beta

      project = local.serverless_project_id
      service = "artifactregistry.googleapis.com"
    }

    resource "google_project_service_identity" "pubsub_sa" {
      provider = google-beta

      project = local.serverless_project_id
      service = "pubsub.googleapis.com"
    }

    data "google_storage_project_service_account" "gcs_account" {
      project = local.serverless_project_id
    }

    resource "time_sleep" "sa_propagation" {
      create_duration = "60s"

      depends_on = [
        google_project_service_identity.cloudfunction_sa,
        google_project_service_identity.artifact_sa,
        google_project_service_identity.pubsub_sa,
        google_project_service_identity.eventarc_sa,
        data.google_storage_project_service_account.gcs_account,
      ]
    }

    module "cloud_function_kms" {
      source  = "terraform-google-modules/kms/google"
      version = "~> 2.2"

      project_id           = local.security_project_id
      location             = local.location
      keyring              = local.keyring_name
      keys                 = [local.key_name]
      set_decrypters_for   = length(local.decrypters) > 0 ? [local.key_name] : []
      set_encrypters_for   = length(local.encrypters) > 0 ? [local.key_name] : []
      decrypters           = [join(",", local.decrypters)]
      encrypters           = [join(",", local.encrypters)]
      prevent_destroy      = false
      key_rotation_period  = "7776000s"
      key_protection_level = "HSM"

      depends_on = [
        time_sleep.sa_propagation,
      ]
    }

    module "cloud_function_core" {
      source  = "GoogleCloudPlatform/cloud-functions/google//modules/secure-cloud-function-core"
      version = "~> 0.4.0"

      function_name        = "secure-cloud-function-bigquery"
      function_description = "Logs when there is a new row in the BigQuery"
      project_id           = local.serverless_project_id
      project_number       = local.serverless_project_number
      location             = local.location
      runtime              = "go118"
      entry_point          = "HelloCloudFunction"
      force_destroy        = true
      encryption_key       = module.cloud_function_kms.keys[local.key_name]
      network_id           = "projects/${local.restricted_host_project_id}/global/networks/${local.restricted_network_name}"

      storage_source = {
        bucket = local.cloudfunction_source_bucket_name
        object = google_storage_bucket_object.cf_bigquery_source_zip.name
      }

      labels = {
        env      = "production"
        billable = "true"
      }

      event_trigger = {
        event_type            = "google.cloud.audit.log.v1.written"
        trigger_region        = local.location
        service_account_email = local.serverless_service_account_email
        retry_policy          = "RETRY_POLICY_RETRY"
        event_filters = [
          {
            attribute       = "serviceName"
            attribute_value = "bigquery.googleapis.com"
          },
          {
            attribute       = "methodName"
            attribute_value = "google.cloud.bigquery.v2.JobService.InsertJob"
          },
          {
            attribute       = "resourceName"
            attribute_value = module.bigquery.bigquery_tables[local.table_name]["id"]
            operator        = "match-path-pattern" # This allows path patterns to be used in the value field
          }
        ]
      }

      # IPs used on Secure Web Proxy
      build_environment_variables = {
        HTTP_PROXY  = "http://${local.restricted_subnet_secure_web_proxy_ip[local.location]}:443"
        HTTPS_PROXY = "http://${local.restricted_subnet_secure_web_proxy_ip[local.location]}:443"
      }


      service_config = {
        max_instance_count             = 2
        min_instance_count             = 1
        available_memory               = "256Mi"
        timeout_seconds                = 120
        vpc_connector                  = local.restricted_serverless_network_connector_id
        service_account_email          = local.serverless_service_account_email
        ingress_settings               = "ALLOW_INTERNAL_AND_GCLB"
        all_traffic_on_latest_revision = true
        vpc_connector_egress_settings  = "ALL_TRAFFIC"

        runtime_env_variables = {
          PROJECT_ID = local.serverless_project_id
          NAME       = "cloud function v2"
        }
      }

      depends_on = [
        google_service_account_iam_member.identity_service_account_user,
        module.bigquery,
        google_storage_bucket_object.cf_bigquery_source_zip
      ]
    }
    ```

1. Commit changes in the `bu1-scf-app` repository and push the code to the `plan` branch. Wait for the `plan` build to finish before proceeding with the next step.

    ```bash
    git add .
    git commit -m "Secure Cloud Function initial commit"
    git push --set-upstream origin plan
    ```

1. Merge changes to the production branch and push the branch.

    ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

1. You can see the Secure Cloud Function running, doing an insert at the Bigquery table.
    1. Go to the [BigQuery console](https://console.cloud.google.com/bigquery).
    1. Select the Serverless project created.
    1. Create a new Query.
    1. Run the following INSERT command:

        ```sql
        INSERT INTO `<SERVERLESS_PROJECT_ID>.dst_secure_cloud_function.tbl_test` VALUES
        ("AX","American Express","American Express","30006041298416","Gerson Beahan","688","09/2008","04/2013","26",9287,"77443")
        ```

    1. Go to the [Cloud Function console](https://console.cloud.google.com/functions).
    1. Select the Serverless project and the `secure-cloud-function-bigquery` Cloud Function.
    1. Go to the logs.
    1. After the insert is processed, you can see the logs with the buckets and regions at the Serverless Project Cloud Function Logs.

### 3-networks: Add flag to disable the Secure Web Proxy used by the Secure Cloud Function build process

1. The usage of the Secure Web Proxy in the restricted host project will incur in additional costs.
See the [Secure Web Proxy pricing information](https://cloud.google.com/secure-web-proxy/pricing) for details.
1. Apply the following instructions to create a toggle to enable/disable the Secure Web Proxy
1. Update file `gcp-networks/modules/base_env/variables.tf` to create a toggle for the deploy of the Secure Web Proxy:

    ```hcl
    variable "enable_swp" {
      description = "Set to true to create the Secure Web Proxy needed by the Secure Cloud Function build process."
      type        = bool
      default     = false
    }
    ```

1. Update file `gcp-networks/envs/production/main.tf` to set the toggle to `true` and set the `restricted_subnet_secure_web_proxy_ip`:

    ```hcl
    module "base_env" {
      source = "../../modules/base_env"

      env                                   = local.env
      environment_code                      = local.environment_code
      access_context_manager_policy_id      = var.access_context_manager_policy_id

    ...

      enable_scf = true
      enable_swp = false

      restricted_subnet_secure_web_proxy_ip = local.restricted_subnet_secure_web_proxy_ip
    }
    ```
1. Update file `gcp-networks/modules/base_env/scf_secure_web_proxy.tf` and add the new flag:

    ```hcl
    resource "null_resource" "generate_certificate" {
      count = var.enable_scf && var.enable_swp ? 1 : 0
      ...
    ```

    ```hcl
    resource "time_sleep" "wait_upload_certificate" {
      count = var.enable_scf && var.enable_swp ? 1 : 0
      ...
    ```

    ```hcl
    module "secure_web_proxy" {
      source = "github.com/GoogleCloudPlatform/terraform-google-cloud-functions//modules/secure-web-proxy"
      count  = var.enable_scf && var.enable_swp ? 1 : 0
      ...
    ```

1. Commit changes in the `gcp-networks` repository and push the code to the `production` branch.
