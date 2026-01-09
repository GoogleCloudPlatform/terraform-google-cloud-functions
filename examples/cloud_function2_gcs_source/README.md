# Simple Example

This example illustrates how to use the `cloud-functions` module.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| location | The location of this cloud function | `string` | `"us-central1"` | no |
| project\_id | The ID of the project in which to provision resources. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| function\_name | Name of the Cloud Function (Gen 2) |
| function\_uri | URI of the Cloud Function (Gen 2) |
| location | Location of the Cloud Function (Gen 2) |
| project\_id | The project ID |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

To provision this example, run the following from within this directory:
- `terraform init` to get the plugins
- `terraform plan` to see the infrastructure plan
- `terraform apply` to apply the infrastructure build
- `terraform destroy` to destroy the built infrastructure
