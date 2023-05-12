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

variable "zone" {
  description = "The zone where Webserver VM is going to be deployed."
  type        = string
}

# variable "webserver_instance" {
#   description = "The name used for the webserver instance."
#   type        = string
# }

######

variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
}

variable "function_location" {
  description = "The location of this cloud function"
  type        = string
  default     = "us-central1"
}
