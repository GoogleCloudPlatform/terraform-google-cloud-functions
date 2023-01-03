/**
 * Copyright 2021 Google LLC
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

module "cloud_functions2" {
  source = "../.."

  project_id        = var.project_id
  function_name     = "function2-pubsub-trigger"
  function_location = "us-central1"
  runtime           = "python38"
  entrypoint        = "hello_http"
  storage_source = {
    bucketname = "dc-in-lz-pr-poc-01_cloudbuild"
    object     = "cf_source_sample/cf_sample_func.zip"
    generation = null
  }
  event_trigger = {
    trigger_region        = "us-central1"
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    service_account_email = null
    pubsub_topic          = "projects/${var.project_id}/topics/${var.pubsub_topic}"
    retry_policy          = "RETRY_POLICY_RETRY"
    event_filters         = null
  }
}
