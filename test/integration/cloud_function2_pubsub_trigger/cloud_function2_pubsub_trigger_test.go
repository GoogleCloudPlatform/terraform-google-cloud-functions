// Copyright 2022 Google LLC
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

package cloud_function2_pubsub_trigger

import (
	"fmt"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
)

func TestGCF2PubSubTrigger(t *testing.T) {
	pubsub_triggerT := tft.NewTFBlueprintTest(t)

	pubsub_triggerT.DefineVerify(func(assert *assert.Assertions) {
		// Removing DefaultVerify because Cloud Function API is changing the build_config/source/storage_source/generation and this modification is breaking the build validation.
		// pubsub_triggerT.DefaultVerify(assert)

		function_name := pubsub_triggerT.GetStringOutput("function_name")
		pubsubTopic := pubsub_triggerT.GetStringOutput("pubsub_topic")
		projectID := pubsub_triggerT.GetStringOutput("project_id")
		location := pubsub_triggerT.GetStringOutput("location")

		function_cmd := gcloud.Run(t, "functions describe", gcloud.WithCommonArgs([]string{function_name, "--project", projectID, "--gen2", "--region", location, "--format", "json"}))

		// T01: Verify if the Cloud Functions deployed is in ACTIVE state
		assert.Equal("ACTIVE", function_cmd.Get("state").String(), fmt.Sprintf("Should be ACTIVE. Cloud Function is not successfully deployed."))

		// T02: Verify if the Cloud Functions with PubSub Event Trigger is deployed matching the output
		// Topic format: projects/<PROJECT_ID>/topic/<TOPICNAME>
		// Output: <TOPICNAME>
		assert.Contains(function_cmd.Get("eventTrigger.pubsubTopic").String(), pubsubTopic, fmt.Sprintf("Event Trigger is not based on PubSub Topic provided in variables. Check the EventType configuration."))
	})
	pubsub_triggerT.Test()
}
