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

package secure_cloud_function_with_sql

import (
	"fmt"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
)

func TestGCF2CloudSQL(t *testing.T) {
	cf2SQL := tft.NewTFBlueprintTest(t)

	cf2SQL.DefineVerify(func(assert *assert.Assertions) {
		cf2SQL.DefaultVerify(assert)

		name := cf2SQL.GetStringOutput("cloud_function_name")
		location := "us-central1"
		connectorID := cf2SQL.GetStringOutput("connector_id")
		saEmail := cf2SQL.GetStringOutput("service_account_email")
		mysqlName := cf2SQL.GetStringOutput("mysql_name")
		projectID := cf2SQL.GetStringOutput("serverless_project_id")
		sqlProjectID := cf2SQL.GetStringOutput("cloudsql_project_id")
		topicID := cf2SQL.GetStringOutput("topic_id")
		topicKMS := cf2SQL.GetStringOutput("topic_kms_key")
		sqlKMS := cf2SQL.GetStringOutput("cloud_sql_kms_key")
		scrName := cf2SQL.GetStringOutput("secret_manager_name")

		cf := gcloud.Runf(t, "functions describe %s --project %s --gen2 --region %s", name, projectID, location)
		assert.Equal("ACTIVE", cf.Get("state").String(), "Should be ACTIVE. Cloud Function is not successfully deployed.")
		assert.Equal(connectorID, cf.Get("serviceConfig.vpcConnector").String(), fmt.Sprintf("VPC Connector should be %s. Connector was not set.", connectorID))
		assert.Equal("PRIVATE_RANGES_ONLY", cf.Get("serviceConfig.vpcConnectorEgressSettings").String(), "Egress setting should be PRIVATE_RANGES_ONLY.")
		assert.Equal("ALLOW_INTERNAL_AND_GCLB", cf.Get("serviceConfig.ingressSettings").String(), "Ingress setting should be ALLOW_INTERNAL_AND_GCLB.")
		assert.Equal(saEmail, cf.Get("serviceConfig.serviceAccountEmail").String(), fmt.Sprintf("Cloud Function should use the service account %s.", saEmail))
		assert.Contains(cf.Get("eventTrigger.eventType").String(), "google.cloud.pubsub.topic.v1.messagePublished", "Event Trigger is not a message published on topic.")
		assert.Equal(cf.Get("eventTrigger.pubsubTopic").String(), topicID, fmt.Sprintf("Event Trigger topic is not %s.", topicID))
		assert.Equal(cf.Get("secretEnvironmentVariables.0.key").String(), "INSTANCE_PWD", "Should have secret environment key INSTANCE_PWD")
		assert.Equal(cf.Get("secretEnvironmentVariables.0.secret").String(), scrName, fmt.Sprintf("Should have secret environment key %s", scrName))

		cf = gcloud.Runf(t, "sql instances describe %s --project %s", mysqlName, sqlProjectID)
		assert.Equal("RUNNABLE", cf.Get("state").String(), "Should be RUNNABLE. Cloud SQL is not successfully deployed.")
		assert.Equal("PRIVATE", cf.Get("ipAddresses.0.type").String(), "Should be PRIVATE. Cloud SQL should have only PRIVATE IPs.")
		assert.Equal(sqlKMS, cf.Get("diskEncryptionConfiguration.kmsKeyName").String(), fmt.Sprintf("Cloud SQL should be encrypting disk with %s", sqlKMS))

		cf = gcloud.Runf(t, "pubsub topics describe %s", topicID)
		assert.Equal(topicKMS, cf.Get("kmsKeyName").String(), fmt.Sprintf("Pub/Sub topic should be encrypting messages with %s", topicKMS))

	})
	cf2SQL.Test()
}
