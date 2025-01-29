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

resource "google_storage_bucket" "bucket" {
  name                        = "${var.project_id}-gcf-source-pubsub"
  location                    = "US"
  uniform_bucket_level_access = true
  project                     = var.project_id
}

resource "google_storage_bucket_object" "function-source" {
  name   = "sample_function_py.zip"
  bucket = google_storage_bucket.bucket.name
  source = "../../helpers/sample_function_py.zip"
}

module "pubsub" {
  source  = "terraform-google-modules/pubsub/google"
  version = "~> 7.0"

  topic      = "function2-topic"
  project_id = var.project_id
}

module "cloud_functions2" {
  source  = "GoogleCloudPlatform/cloud-functions/google"
  version = "~> 0.6"

  project_id        = var.project_id
  function_name     = "function2-pubsub-trigger-py"
  function_location = var.function_location
  runtime           = "python38"
  entrypoint        = "hello_http"
  storage_source = {
    bucket     = google_storage_bucket.bucket.name
    object     = google_storage_bucket_object.function-source.name
    generation = null
  }
  event_trigger = {
    trigger_region        = "us-central1"
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    service_account_email = null
    pubsub_topic          = module.pubsub.id
    retry_policy          = "RETRY_POLICY_RETRY"
    event_filters         = null
  }
}
