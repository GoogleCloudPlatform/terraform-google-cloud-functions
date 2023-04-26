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

output "cloudfunction_name" {
  value       = module.cloud_function.function_name
  description = "Name of the created service."
}

output "eventarc_google_channel_id" {
  value       = google_eventarc_google_channel_config.primary.id
  description = "The ID of the Google Eventarc Channel."
}

output "artifact_registry_repository_id" {
  value       = google_artifact_registry_repository.cloudfunction_repo.id
  description = "The ID of the Artifact Registry created to store Cloud Function images."
}

output "cloudbuild_worker_pool" {
  value       = google_cloudbuild_worker_pool.pool.id
  description = "The ID of the Cloud Build worker pool created to build Cloud Function images."
}

output "cloudfunction_bucket_name" {
  value       = module.cloudfunction_bucket.name
  description = "Name of the Cloud Function source bucket."
}

output "cloudfunction_bucket" {
  value       = module.cloudfunction_bucket.bucket
  description = "The Cloud Function source bucket."
}

output "cloudfunction_url" {
  value       = module.cloud_function.function_uri
  description = "The URL on which the deployed service is available."
}
