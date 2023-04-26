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
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
)

func TestGCF2BigqueryTrigger(t *testing.T) {
	bigQueryTriggerT := tft.NewTFBlueprintTest(t)

	bigQueryTriggerT.DefineVerify(func(assert *assert.Assertions) {
		bigQueryTriggerT.DefaultVerify(assert)

		function_location := "us-west1"
		function_name := bigQueryTriggerT.GetStringOutput("cloud_function_name")
		projectID := bigQueryTriggerT.GetStringOutput("serverless_project_id")
		connector_id := bigQueryTriggerT.GetStringOutput("connector_id")
		service_account_email := bigQueryTriggerT.GetStringOutput("service_account_email")
		// artifact_registry_repository_id := bigQueryTriggerT.GetStringOutput("artifact_registry_repository_id")
		// table_id := bigQueryTriggerT.GetStringOutput("table_id")
		// bigQueryTableID := bigQueryTriggerT.GetStringOutput("table_id")

		function_cmd := gcloud.Run(t, "functions describe", gcloud.WithCommonArgs([]string{function_name, "--project", projectID, "--gen2", "--region", function_location, "--format", "json"}))

		assert.Equal("ACTIVE", function_cmd.Get("state").String(), fmt.Sprintf("Should be ACTIVE. Cloud Function is not successfully deployed."))
		assert.Equal(connector_id, function_cmd.Get("vpcConnector").String(), fmt.Sprintf("VPC Connector should be %s. Connector was not set.", connector_id))
		assert.Equal("PRIVATE_RANGES_ONLY", function_cmd.Get("vpcConnectorEgressSettings").String(), fmt.Sprintf("Egress setting should be PRIVATE_RANGES_ONLY."))
		assert.Equal("ALLOW_INTERNAL_AND_GCLB", function_cmd.Get("ingressSettings").String(), fmt.Sprintf("Ingress setting should be ALLOW_INTERNAL_AND_GCLB."))
		assert.Equal(service_account_email, function_cmd.Get("serviceAccountEmail").String(), fmt.Sprintf("Cloud Function should use the service account %s.", service_account_email))
		assert.Contains(function_cmd.Get("eventTrigger.eventType").String(), "google.cloud.audit.log.v1.written", fmt.Sprintf("Event Trigger is not based on Audit Logs. Check the EventType configuration."))

		// artifact_registry_cmd := gcloud.Run(t, "functions describe", gcloud.WithCommonArgs([]string{artifact_registry_repository_id, "--project", projectID, "--gen2", "--region", function_location, "--format", "json"}))
	})
	bigQueryTriggerT.Test()
}
