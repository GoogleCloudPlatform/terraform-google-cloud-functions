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
	pubsub_triggerT := tft.NewTFBlueprintTest(t)

	pubsub_triggerT.DefineVerify(func(assert *assert.Assertions) {
		pubsub_triggerT.DefaultVerify(assert)

		function_name := pubsub_triggerT.GetStringOutput("cloud_function_name")
		bigQueryTableID := pubsub_triggerT.GetStringOutput("table_id")
		projectID := pubsub_triggerT.GetStringOutput("serverless_project_id")
		function_location := "us-west1"

		function_cmd := gcloud.Run(t, "functions describe", gcloud.WithCommonArgs([]string{function_name, "--project", projectID, "--gen2", "--region", function_location, "--format", "json"}))

		assert.Equal("ACTIVE", function_cmd.Get("state").String(), fmt.Sprintf("Should be ACTIVE. Cloud Function is not successfully deployed."))

		assert.Contains(function_cmd.Get("eventTrigger.eventType").String(), "google.cloud.audit.log.v1.written", fmt.Sprintf("Event Trigger is not based on Audit Logs. Check the EventType configuration."))
	})
	pubsub_triggerT.Test()
}
