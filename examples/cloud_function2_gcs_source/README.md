# Simple Example

This example illustrates how to use the `cloud-functions` module.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project\_id | The ID of the project in which to provision resources. | `string` | `"dc-in-lz-pr-poc-01"` | no |

## Outputs

| Name | Description |
|------|-------------|
| function\_name | Name of the Cloud Function (Gen 2) |
| function\_uri | URI of the Cloud Function (Gen 2) |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

To provision this example, run the following from within this directory:
- `terraform init` to get the plugins
- `terraform plan` to see the infrastructure plan
- `terraform apply` to apply the infrastructure build
- `terraform destroy` to destroy the built infrastructure
