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
#
# Important information for understanding the script:
# https://cloud.google.com/kms/docs/encrypt-decrypt
# https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets

set -e

terraform_service_account=${1}
instance_name=${2}
instance_project_id=${3}
user_name=${4}
host=${5}

destroy_user() {

    gcloud sql users delete "${user_name}" \
    --instance "${instance_name}" \
    --impersonate-service-account="${terraform_service_account}" \
    --host="${host}" \
    --project="${instance_project_id}"
}

destroy_user
