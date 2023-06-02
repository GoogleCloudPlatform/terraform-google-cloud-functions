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

output "connector_id" {
  value       = module.cloud_serverless_network.connector_id
  description = "VPC serverless connector ID."
}

output "keyring_self_link" {
  value       = module.cloud_serverless_security.keyring_self_link
  description = "Name of the Cloud KMS keyring."
}

output "key_self_link" {
  value       = module.cloud_serverless_security.key_self_link
  description = "Name of the Cloud KMS crypto key."
}

output "cloudfunction_name" {
  value       = module.cloud_function_core.cloudfunction_name
  description = "ID of the created Cloud Function."
}

output "cloudfunction_url" {
  value       = module.cloud_function_core.cloudfunction_url
  description = "Url of the created Cloud Function."
}

output "cloudfunction_bucket_name" {
  value       = module.cloud_function_core.cloudfunction_bucket_name
  description = "The Cloud Function source bucket."
}

output "cloudfunction_bucket" {
  value       = module.cloud_function_core.cloudfunction_bucket
  description = "The Cloud Function source bucket."
}

output "gca_vpcaccess_sa" {
  value       = module.cloud_serverless_network.gca_vpcaccess_sa
  description = "Service Account for VPC Access."
}

output "cloud_services_sa" {
  value       = module.cloud_serverless_network.cloud_services_sa
  description = "Service Account for Cloud Function."
}

output "serverless_identity_services_sa" {
  value       = google_project_service_identity.cloudfunction_sa.email
  description = "Service Identity to serverless services."
}
