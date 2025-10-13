// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package cloud_function_internal_server

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
	"github.com/tidwall/gjson"
)

var (
	RetryableTransientErrors = map[string]string{
		// Error code 409 for concurrent policy changes.
		".*Error 409.*There were concurrent policy changes.*": "Concurrent policy changes.",

		// API Rate limit exceeded errors can be retried.
		".*rateLimitExceeded.*": "Rate limit exceeded.",

		// Project deletion is eventually consistent. Even if google_project resources inside the folder are deleted there may be a deletion error.
		".*FOLDER_TO_DELETE_NON_EMPTY_VIOLATION.*": "Failed to delete non empty folder.",

		// Granting IAM Roles is eventually consistent.
		".*Error 403.*Permission.*denied on resource.*": "Permission denied on resource.",

		// Editing VPC Service Controls is eventually consistent.
		".*Error 403.*Request is prohibited by organization's policy.*vpcServiceControlsUniqueIdentifier.*":    "Request is prohibited by organization's policy.",
		".*Error code 7.*Request is prohibited by organization's policy.*vpcServiceControlsUniqueIdentifier.*": "Request is prohibited by organization's policy.",

		// Google Storage Service Agent propagation issue.
		".*Error 400.*Service account service-.*@gs-project-accounts.iam.gserviceaccount.com does not exist.*": "Google Storage Service Agent propagation issue",
	}
)

type Protocols struct {
	Protocol string
	Ports    []string
}

func GetLastSplitElement(value string, sep string) string {
	splitted := strings.Split(value, sep)
	return splitted[len(splitted)-1]
}

func GetResultFieldStrSlice(rs []gjson.Result, field string) []string {
	s := make([]string, 0)
	for _, r := range rs {
		s = append(s, r.Get(field).String())
	}
	return s
}

// GetOrgACMPolicyID gets the Organization Access Context Manager Policy ID
func GetOrgACMPolicyID(t testing.TB, orgID string) string {
	filter := fmt.Sprintf("parent:organizations/%s", orgID)
	id := gcloud.Runf(t, "access-context-manager policies list --organization %s --filter %s --quiet", orgID, filter).Array()
	if len(id) == 0 {
		return ""
	}
	return GetLastSplitElement(id[0].Get("name").String(), "/")
}

func TestCFInternalServer(t *testing.T) {
	orgID := utils.ValFromEnv(t, "TF_VAR_org_id")
	policyID := GetOrgACMPolicyID(t, orgID)
	createACM := false

	vars := map[string]interface{}{
		"create_access_context_manager_access_policy": createACM,
		"access_context_manager_policy_id":            policyID,
	}

	if policyID == "" {
		createACM = true
		vars = map[string]interface{}{
			"create_access_context_manager_access_policy": createACM,
		}
	}

	cft := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(RetryableTransientErrors, 5, 1*time.Minute),
	)

	cft.DefineVerify(func(assert *assert.Assertions) {
		// Removing DefaultVerify because Cloud Function API is changing the build_config/source/storage_source/generation and this modification is breaking the build validation.
		// cft.DefaultVerify(assert)

		location := "us-west1"
		networkProjectID := cft.GetStringOutput("network_project_id")
		projectID := cft.GetStringOutput("serverless_project_id")
		functionName := cft.GetStringOutput("cloud_function_name")
		connectorID := cft.GetStringOutput("connector_id")
		saEmail := cft.GetStringOutput("service_account_email")

		cf := gcloud.Runf(t, "functions describe %s --project %s --gen2 --region %s", functionName, projectID, location)
		cfTrigger := cf.Get("eventTrigger.trigger")
		assert.Equal("ACTIVE", cf.Get("state").String(), "Should be ACTIVE. Cloud Function is not successfully deployed.")
		assert.Equal(connectorID, cf.Get("serviceConfig.vpcConnector").String(), fmt.Sprintf("VPC Connector should be %s. Connector was not set.", connectorID))
		assert.Equal("ALL_TRAFFIC", cf.Get("serviceConfig.vpcConnectorEgressSettings").String(), "Egress setting should be ALL_TRAFFIC.")
		assert.Equal("ALLOW_INTERNAL_AND_GCLB", cf.Get("serviceConfig.ingressSettings").String(), "Ingress setting should be ALLOW_INTERNAL_AND_GCLB.")
		assert.Equal(saEmail, cf.Get("serviceConfig.serviceAccountEmail").String(), fmt.Sprintf("Cloud Function should use the service account %s.", saEmail))
		assert.Equal("google.cloud.storage.object.v1.finalized", cf.Get("eventTrigger.eventType").String(), "Cloud Function EventType should be google.cloud.storage.object.v1.finalized.")
		assert.NotNil(t, cfTrigger, "Trigger should exist.")

		gcloudArgsBucket := gcloud.WithCommonArgs([]string{"--project", projectID, "--json"})
		bucketName := cft.GetStringOutput("cloudfunction_bucket_name")
		opBucket := gcloud.Run(t, fmt.Sprintf("alpha storage ls --buckets gs://%s", bucketName), gcloudArgsBucket).Array()
		assert.Equal(bucketName, opBucket[0].Get("metadata.name").String(), fmt.Sprintf("The bucket name should be %s.", bucketName))
		assert.True(opBucket[0].Exists(), "Bucket %s should exist.", bucketName)

		instanceName := "webserver"
		instanceZone := fmt.Sprintf("https://www.googleapis.com/compute/v1/projects/%s/zones/us-west1-b", projectID)
		opInstance := gcloud.Runf(t, "compute instances describe %s --zone=us-west1-b --project=%s", instanceName, projectID)
		assert.Equal(instanceName, opInstance.Get("name").String(), fmt.Sprintf("Instance name should be %s", instanceName))
		assert.Equal(instanceZone, opInstance.Get("zone").String(), fmt.Sprintf("Instance should be in zone %s", instanceZone))

		denyAllEgressName := "fw-e-shared-restricted-internal-server"
		denyAllEgressRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", denyAllEgressName, networkProjectID)
		assert.Equal(denyAllEgressName, denyAllEgressRule.Get("name").String(), fmt.Sprintf("firewall rule %s should exist", denyAllEgressName))
		assert.Equal("EGRESS", denyAllEgressRule.Get("direction").String(), fmt.Sprintf("firewall rule %s direction should be EGRESS", denyAllEgressName))
		assert.True(denyAllEgressRule.Get("logConfig.enable").Bool(), fmt.Sprintf("firewall rule %s should have log configuration enabled", denyAllEgressName))
		assert.Equal("10.0.0.0/28", denyAllEgressRule.Get("destinationRanges").Array()[0].String(), fmt.Sprintf("firewall rule %s destination ranges should be 10.0.0.0/28", denyAllEgressName))
		assert.Equal("8000", denyAllEgressRule.Get("allowed.0.ports.0").String(), fmt.Sprintf("firewall rule %s should allow port 8000", denyAllEgressName))

	})
	cft.Test()
}
