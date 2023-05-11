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

output "serverless_project_id" {
  value       = module.secure_harness.serverless_project_ids[0]
  description = "The serverless project id."
}

output "serverless_project_number" {
  value       = module.secure_harness.serverless_project_numbers[module.secure_harness.serverless_project_ids[0]]
  description = "The serverless project number."
}

output "security_project_id" {
  value       = module.secure_harness.security_project_id
  description = "The security project id."
}

output "security_project_number" {
  value       = module.secure_harness.security_project_number
  description = "The security project number."
}

output "network_project_id" {
  value       = module.secure_harness.network_project_id[0]
  description = "The network project id."
}

output "service_account_email" {
  value       = module.secure_harness.service_account_email[module.secure_harness.serverless_project_ids[0]]
  description = "The service account email created to be used by Cloud Function."
}

output "cloud_function_name" {
  value       = module.secure_cloud_function.cloudfunction_name
  description = "The service account email created to be used by Cloud Function."
}

output "service_vpc_self_link" {
  value       = module.secure_harness.service_vpc[0].network.self_link
  description = "The Network self-link created in harness."
}

output "service_vpc_name" {
  value       = module.secure_harness.service_vpc[0].network_name
  description = "The Network self-link created in harness."
}

output "service_vpc_subnet_name" {
  value       = module.secure_harness.service_subnet[0]
  description = "The sub-network name created in harness."
}

output "connector_id" {
  value       = module.secure_cloud_function.connector_id
  description = "VPC serverless connector ID."
}

output "restricted_service_perimeter_name" {
  value       = module.secure_harness.restricted_service_perimeter_name
  description = "Service Perimeter name."
}

output "restricted_access_level_name" {
  value       = module.secure_harness.restricted_access_level_name
  description = "Access level name."
}

output "mysql_name" {
  description = "The name for Cloud SQL instance"
  value       = module.safer_mysql_db.instance_name
}

output "mysql_conn" {
  value       = module.safer_mysql_db.instance_connection_name
  description = "The connection name of the master instance to be used in connection strings"
}

output "mysql_public_ip_address" {
  description = "The first public (PRIMARY) IPv4 address assigned for the master instance"
  value       = module.safer_mysql_db.public_ip_address
}

output "mysql_private_ip_address" {
  description = "The first private (PRIVATE) IPv4 address assigned for the master instance"
  value       = module.safer_mysql_db.private_ip_address
}


# output "cloudfunction_bucket_name" {
#   value       = module.secure_cloud_function.cloudfunction_bucket_name
#   description = "Name of the Cloud Function source bucket."
# }

# output "cloudfunction_bucket" {
#   value       = module.secure_cloud_function.cloudfunction_bucket
#   description = "The Cloud Function source bucket."
# }

# output "cloudfunction_url" {
#   value       = module.secure_cloud_function.cloudfunction_url
#   description = "The URL on which the deployed service is available."
# }
