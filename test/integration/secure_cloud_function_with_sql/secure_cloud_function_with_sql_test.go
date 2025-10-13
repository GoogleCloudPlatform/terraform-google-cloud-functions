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
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
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

// GetOrgACMPolicyID gets the Organization Access Context Manager Policy ID
func GetOrgACMPolicyID(t testing.TB, orgID string) string {
	filter := fmt.Sprintf("parent:organizations/%s", orgID)
	id := gcloud.Runf(t, "access-context-manager policies list --organization %s --filter %s --quiet", orgID, filter).Array()
	if len(id) == 0 {
		return ""
	}
	return GetLastSplitElement(id[0].Get("name").String(), "/")
}

func GetLastSplitElement(value string, sep string) string {
	splitted := strings.Split(value, sep)
	return splitted[len(splitted)-1]
}

func TestGCF2CloudSQL(t *testing.T) {
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

	cf2SQL := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(RetryableTransientErrors, 5, 1*time.Minute),
	)

	cf2SQL.DefineVerify(func(assert *assert.Assertions) {
		// Removing DefaultVerify because Cloud Function API is changing the build_config/source/storage_source/generation and this modification is breaking the build validation.
		// cf2SQL.DefaultVerify(assert)

		name := cf2SQL.GetStringOutput("cloud_function_name")
		location := "us-central1"
		connectorID := cf2SQL.GetStringOutput("connector_id")
		saEmail := cf2SQL.GetStringOutput("service_account_email")
		mysqlName := cf2SQL.GetStringOutput("mysql_name")
		mysqlUser := cf2SQL.GetStringOutput("mysql_user")
		mySQLPrivIP := cf2SQL.GetStringOutput("mysql_private_ip_address")
		projectID := cf2SQL.GetStringOutput("serverless_project_id")
		netProjectID := cf2SQL.GetStringOutput("network_project_id")
		sqlProjectID := cf2SQL.GetStringOutput("cloudsql_project_id")
		secProjectID := cf2SQL.GetStringOutput("security_project_id")
		topicID := cf2SQL.GetStringOutput("topic_id")
		topicKMS := cf2SQL.GetStringOutput("topic_kms_key")
		sqlKMS := cf2SQL.GetStringOutput("cloud_sql_kms_key")
		scrName := cf2SQL.GetStringOutput("secret_manager_name")
		schName := cf2SQL.GetStringOutput("scheduler_name")
		secretName := cf2SQL.GetStringOutput("secret_manager_name")
		secretVersion := cf2SQL.GetStringOutput("secret_manager_version")
		secretKMS := cf2SQL.GetStringOutput("secret_kms_key")
		sctVersionFull := fmt.Sprintf("%s/cryptoKeyVersions/%s", secretKMS, secretVersion)

		cf := gcloud.Runf(t, "functions describe %s --project %s --gen2 --region %s", name, projectID, location)
		assert.Equal("ACTIVE", cf.Get("state").String(), "Should be ACTIVE. Cloud Function is not successfully deployed.")
		assert.Equal(connectorID, cf.Get("serviceConfig.vpcConnector").String(), fmt.Sprintf("VPC Connector should be %s. Connector was not set.", connectorID))
		assert.Equal("ALL_TRAFFIC", cf.Get("serviceConfig.vpcConnectorEgressSettings").String(), "Egress setting should be ALL_TRAFFIC.")
		assert.Equal("ALLOW_INTERNAL_AND_GCLB", cf.Get("serviceConfig.ingressSettings").String(), "Ingress setting should be ALLOW_INTERNAL_AND_GCLB.")
		assert.Equal(saEmail, cf.Get("serviceConfig.serviceAccountEmail").String(), fmt.Sprintf("Cloud Function should use the service account %s.", saEmail))
		assert.Equal("google.cloud.pubsub.topic.v1.messagePublished", cf.Get("eventTrigger.eventType").String(), "Event Trigger is not a message published on topic.")
		assert.Equal(topicID, cf.Get("eventTrigger.pubsubTopic").String(), fmt.Sprintf("Event Trigger topic is not %s.", topicID))
		assert.Equal("INSTANCE_PWD", cf.Get("serviceConfig.secretEnvironmentVariables.0.key").String(), "Should have secret environment key INSTANCE_PWD")
		assert.Equal(scrName, cf.Get("serviceConfig.secretEnvironmentVariables.0.secret").String(), fmt.Sprintf("Should have secret environment key %s", scrName))
		assert.Equal("db-application", cf.Get("serviceConfig.environmentVariables.DATABASE_NAME").String(), "SShould have env var DATABASE_NAME with value db-application")
		assert.Equal(location, cf.Get("serviceConfig.environmentVariables.INSTANCE_LOCATION").String(), fmt.Sprintf("Should have env var INSTANCE_LOCATION with value %s", location))
		assert.Equal(mysqlName, cf.Get("serviceConfig.environmentVariables.INSTANCE_NAME").String(), fmt.Sprintf("Should have env var INSTANCE_NAME with value %s", mysqlName))
		assert.Equal(mysqlUser, cf.Get("serviceConfig.environmentVariables.INSTANCE_USER").String(), fmt.Sprintf("Should have environment var INSTANCE_USER with value %s", mysqlUser))
		assert.Equal(sqlProjectID, cf.Get("serviceConfig.environmentVariables.INSTANCE_PROJECT_ID").String(), fmt.Sprintf("Should have environment var with value %s", sqlProjectID))

		cf = gcloud.Runf(t, "sql instances describe %s --project %s", mysqlName, sqlProjectID)
		assert.Equal("RUNNABLE", cf.Get("state").String(), "Should be RUNNABLE. Cloud SQL is not successfully deployed.")
		assert.Equal("PRIVATE", cf.Get("ipAddresses.0.type").String(), "Should be PRIVATE. Cloud SQL should have only PRIVATE IPs.")
		assert.Equal(sqlKMS, cf.Get("diskEncryptionConfiguration.kmsKeyName").String(), fmt.Sprintf("Cloud SQL should be encrypting disk with %s", sqlKMS))

		cf = gcloud.Runf(t, "pubsub topics describe %s", topicID)
		assert.Equal(topicKMS, cf.Get("kmsKeyName").String(), fmt.Sprintf("Pub/Sub topic should be encrypting messages with %s", topicKMS))

		cf = gcloud.Runf(t, "scheduler jobs describe %s --project %s --location %s", schName, projectID, location)
		assert.Equal(topicID, cf.Get("pubsubTarget.topicName").String(), fmt.Sprintf("Scheduler should publish messages in topic %s", topicID))

		cf = gcloud.Runf(t, "secrets describe %s --project %s", secretName, secProjectID)
		assert.Equal(secretKMS, cf.Get("replication.userManaged.replicas.0.customerManagedEncryption.kmsKeyName").String(), fmt.Sprintf("Secret should have KMS key configured %s", secretKMS))
		cf = gcloud.Runf(t, "secrets versions describe %s --secret  %s --project %s", secretVersion, secretName, secProjectID)
		assert.Equal(sctVersionFull, cf.Get("replicationStatus.userManaged.replicas.0.customerManagedEncryption.kmsKeyVersionName").String(), fmt.Sprintf("Secret should have KMS key configured %s", secretKMS))

		allowTCP3307 := "fw-allow-tcp-3307-egress-to-sql-private-ip"
		allowTCP3307Rule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", allowTCP3307, netProjectID)
		assert.Equal(allowTCP3307, allowTCP3307Rule.Get("name").String(), fmt.Sprintf("firewall rule %s should exist", allowTCP3307))
		assert.Equal("EGRESS", allowTCP3307Rule.Get("direction").String(), fmt.Sprintf("firewall rule %s direction should be EGRESS", allowTCP3307))
		assert.True(allowTCP3307Rule.Get("logConfig.enable").Bool(), fmt.Sprintf("firewall rule %s should have log configuration enabled", allowTCP3307))
		assert.Equal(mySQLPrivIP, allowTCP3307Rule.Get("destinationRanges").Array()[0].String(), fmt.Sprintf("firewall rule %s destination ranges should be %s", allowTCP3307, mySQLPrivIP))
		assert.Equal(1, len(allowTCP3307Rule.Get("allowed").Array()), fmt.Sprintf("firewall rule %s should have only one allowed", allowTCP3307))
		assert.Equal(1, len(allowTCP3307Rule.Get("allowed.0.ports").Array()), fmt.Sprintf("firewall rule %s should allow only one protocol and one port", allowTCP3307))
		assert.Equal("tcp", allowTCP3307Rule.Get("allowed.0.IPProtocol").String(), fmt.Sprintf("firewall rule %s should allow only TCP protocols", allowTCP3307))
		assert.Equal("3307", allowTCP3307Rule.Get("allowed.0.ports.0").String(), fmt.Sprintf("firewall rule %s should allow only port 3307", allowTCP3307))

	})
	cf2SQL.Test()
}
