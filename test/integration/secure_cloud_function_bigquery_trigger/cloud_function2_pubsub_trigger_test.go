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

package cloud_function2_bigquery_trigger

import (
	"fmt"
	"strings"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
)

func GetLastSplitElement(value string, sep string) string {
	splitted := strings.Split(value, sep)
	return splitted[len(splitted)-1]
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

func TestGCF2BigqueryTrigger(t *testing.T) {
	orgID := utils.ValFromEnv(t, "TF_VAR_org_id")
	policyID := GetOrgACMPolicyID(t, orgID)
	vars := map[string]interface{}{
		"access_context_manager_policy_id": policyID,
	}

	bqt := tft.NewTFBlueprintTest(t, tft.WithVars(vars))

	bqt.DefineVerify(func(assert *assert.Assertions) {
		bqt.DefaultVerify(assert)

		location := "us-west1"
		name := bqt.GetStringOutput("cloud_function_name")
		projectID := bqt.GetStringOutput("serverless_project_id")
		connectorID := bqt.GetStringOutput("connector_id")
		saEmail := bqt.GetStringOutput("service_account_email")
		// artifact_registry_repository_id := bqt.GetStringOutput("artifact_registry_repository_id")
		// table_id := bqt.GetStringOutput("table_id")
		// bigQueryTableID := bqt.GetStringOutput("table_id")

		function_cmd := gcloud.Runf(t, "functions describe %s --project %s --gen2 --region %s", name, projectID, location)

		assert.Equal("ACTIVE", function_cmd.Get("state").String(), "Should be ACTIVE. Cloud Function is not successfully deployed.")
		assert.Equal(connectorID, function_cmd.Get("serviceConfig.vpcConnector").String(), fmt.Sprintf("VPC Connector should be %s. Connector was not set.", connectorID))
		assert.Equal("PRIVATE_RANGES_ONLY", function_cmd.Get("serviceConfig.vpcConnectorEgressSettings").String(), "Egress setting should be PRIVATE_RANGES_ONLY.")
		assert.Equal("ALLOW_INTERNAL_AND_GCLB", function_cmd.Get("serviceConfig.ingressSettings").String(), "Ingress setting should be ALLOW_INTERNAL_AND_GCLB.")
		assert.Equal(saEmail, function_cmd.Get("serviceAccountEmail").String(), fmt.Sprintf("Cloud Function should use the service account %s.", saEmail))
		assert.Contains(function_cmd.Get("eventTrigger.eventType").String(), "google.cloud.audit.log.v1.written", "Event Trigger is not based on Audit Logs. Check the EventType configuration.")

		// artifact_registry_cmd := gcloud.Run(t, "functions describe", gcloud.WithCommonArgs([]string{artifact_registry_repository_id, "--project", projectID, "--gen2", "--region", location, "--format", "json"}))
	})
	bqt.Test()
}
