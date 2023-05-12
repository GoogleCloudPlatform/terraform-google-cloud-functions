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

resource "google_storage_bucket" "bucket" {
  name                        = "${var.project_id}-gcf-source"
  location                    = "US"
  uniform_bucket_level_access = true
  project                     = var.project_id
}

####
resource "random_id" "random_folder_suffix" {
  byte_length = 2
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "function/cloudfunction-${random_id.random_folder_suffix.hex}.zip"
}

resource "google_storage_bucket_object" "function-source" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"
  name   = "src-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.bucket.name

  depends_on = [
    data.archive_file.source
  ]
}
####

# resource "google_storage_bucket_object" "function-source" {
#   name   = "sample_function_go.zip"
#   bucket = google_storage_bucket.bucket.name
#   source = "../../helpers/sample_function_go.zip"
# }

module "cloud_functions2" {
  source = "../.."

  project_id        = var.project_id
  function_name     = "function2-gcs-webserver-go"
  function_location = var.function_location
  runtime           = "go118"
  entrypoint        = "helloHTTP"
  storage_source = {
    bucket     = google_storage_bucket.bucket.name
    object     = google_storage_bucket_object.function-source.name
    generation = null
  }

}
