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
# https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets

set -e

terraform_service_account=${1}
instance_name=${2}
instance_project_id=${3}
secret_name=${4}
secret_project_id=${5}
user_name=${6}
host=${7}

create_user_and_save_pwd_in_secret() {

    password=$(echo $RANDOM | md5sum | head -c 20; echo;)

    gcloud sql users create "${user_name}" \
    --instance "${instance_name}" \
    --impersonate-service-account="${terraform_service_account}" \
    --password="${password}" \
    --host="${host}" \
    --type="BUILT_IN" \
    --project="${instance_project_id}"


    echo "${password}" | gcloud secrets versions add "${secret_name}" \
    --data-file=- \
    --impersonate-service-account="${terraform_service_account}" \
    --project="${secret_project_id}"
}

create_user_and_save_pwd_in_secret
