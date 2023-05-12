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

project=${1}
#proxy_ip_cidr_range=${2}

firewall_rules=$(gcloud compute firewall-rules list --project="${project}" |grep allow-ssh  |awk -F ' ' '{print $1}')

if [ "${firewall_rules}" == "allow-ssh" ]
then
    echo ""
    echo "-------------------------- Enabling Firewall rules -----------------------"

    gcloud compute firewall-rules update allow-web-server  --no-disabled --project="${project}" --quiet

    gcloud compute firewall-rules update allow-ssh  --no-disabled --project="${project}" --quiet
else
    echo "----------------------Creating firewall rules for proxy instance ----------------------"
    echo ""

#alterar --network para receber variavel
    gcloud compute firewall-rules create allow-web-server --network teste1 --action=ALLOW --rules=tcp:8080 --project="${project}"

    gcloud compute firewall-rules create allow-ssh --network teste1 --direction ingress --action=ALLOW --rules=tcp:22 --rules all --project="${project}"

    #gcloud compute firewall-rules create allow-ssh --network teste1 --direction ingress --action=ALLOW --rules=tcp:22 --rules all --destination-ranges "${proxy_ip_cidr_range}" --project="${project}"
fi