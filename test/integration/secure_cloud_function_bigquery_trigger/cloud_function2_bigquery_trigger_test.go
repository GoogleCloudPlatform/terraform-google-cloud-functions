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
	restrictedServices := []string{
		"accessapproval.googleapis.com",
		"adsdatahub.googleapis.com",
		"aiplatform.googleapis.com",
		"alloydb.googleapis.com",
		"alpha-documentai.googleapis.com",
		"analyticshub.googleapis.com",
		"apigee.googleapis.com",
		"apigeeconnect.googleapis.com",
		"artifactregistry.googleapis.com",
		"assuredworkloads.googleapis.com",
		"automl.googleapis.com",
		"baremetalsolution.googleapis.com",
		"batch.googleapis.com",
		"bigquery.googleapis.com",
		"bigquerydatapolicy.googleapis.com",
		"bigquerydatatransfer.googleapis.com",
		"bigquerymigration.googleapis.com",
		"bigqueryreservation.googleapis.com",
		"bigtable.googleapis.com",
		"binaryauthorization.googleapis.com",
		"cloud.googleapis.com",
		"cloudasset.googleapis.com",
		"cloudbuild.googleapis.com",
		"clouddebugger.googleapis.com",
		"clouddeploy.googleapis.com",
		"clouderrorreporting.googleapis.com",
		"cloudfunctions.googleapis.com",
		"cloudkms.googleapis.com",
		"cloudprofiler.googleapis.com",
		"cloudresourcemanager.googleapis.com",
		"cloudscheduler.googleapis.com",
		"cloudsearch.googleapis.com",
		"cloudtrace.googleapis.com",
		"composer.googleapis.com",
		"compute.googleapis.com",
		"connectgateway.googleapis.com",
		"contactcenterinsights.googleapis.com",
		"container.googleapis.com",
		"containeranalysis.googleapis.com",
		"containerfilesystem.googleapis.com",
		"containerregistry.googleapis.com",
		"containerthreatdetection.googleapis.com",
		"datacatalog.googleapis.com",
		"dataflow.googleapis.com",
		"datafusion.googleapis.com",
		"datamigration.googleapis.com",
		"dataplex.googleapis.com",
		"dataproc.googleapis.com",
		"datastream.googleapis.com",
		"dialogflow.googleapis.com",
		"dlp.googleapis.com",
		"dns.googleapis.com",
		"documentai.googleapis.com",
		"domains.googleapis.com",
		"eventarc.googleapis.com",
		"file.googleapis.com",
		"firebaseappcheck.googleapis.com",
		"firebaserules.googleapis.com",
		"firestore.googleapis.com",
		"gameservices.googleapis.com",
		"gkebackup.googleapis.com",
		"gkeconnect.googleapis.com",
		"gkehub.googleapis.com",
		"healthcare.googleapis.com",
		"iam.googleapis.com",
		"iamcredentials.googleapis.com",
		"iaptunnel.googleapis.com",
		"ids.googleapis.com",
		"integrations.googleapis.com",
		"kmsinventory.googleapis.com",
		"krmapihosting.googleapis.com",
		"language.googleapis.com",
		"lifesciences.googleapis.com",
		"logging.googleapis.com",
		"managedidentities.googleapis.com",
		"memcache.googleapis.com",
		"meshca.googleapis.com",
		"meshconfig.googleapis.com",
		"metastore.googleapis.com",
		"ml.googleapis.com",
		"monitoring.googleapis.com",
		"networkconnectivity.googleapis.com",
		"networkmanagement.googleapis.com",
		"networksecurity.googleapis.com",
		"networkservices.googleapis.com",
		"notebooks.googleapis.com",
		"opsconfigmonitoring.googleapis.com",
		"orgpolicy.googleapis.com",
		"osconfig.googleapis.com",
		"oslogin.googleapis.com",
		"privateca.googleapis.com",
		"pubsub.googleapis.com",
		"pubsublite.googleapis.com",
		"recaptchaenterprise.googleapis.com",
		"recommender.googleapis.com",
		"redis.googleapis.com",
		"retail.googleapis.com",
		"run.googleapis.com",
		"secretmanager.googleapis.com",
		"servicecontrol.googleapis.com",
		"servicedirectory.googleapis.com",
		"spanner.googleapis.com",
		"speakerid.googleapis.com",
		"speech.googleapis.com",
		"sqladmin.googleapis.com",
		"storage.googleapis.com",
		"storagetransfer.googleapis.com",
		"sts.googleapis.com",
		"texttospeech.googleapis.com",
		"timeseriesinsights.googleapis.com",
		"tpu.googleapis.com",
		"trafficdirector.googleapis.com",
		"transcoder.googleapis.com",
		"translate.googleapis.com",
		"videointelligence.googleapis.com",
		"vision.googleapis.com",
		"visionai.googleapis.com",
		"vmmigration.googleapis.com",
		"vpcaccess.googleapis.com",
		"webrisk.googleapis.com",
		"workflows.googleapis.com",
		"workstations.googleapis.com",
	}

	bqt := tft.NewTFBlueprintTest(t, tft.WithVars(vars))

	bqt.DefineVerify(func(assert *assert.Assertions) {
		bqt.DefaultVerify(assert)

		location := "us-west1"
		name := bqt.GetStringOutput("cloud_function_name")
		projectID := bqt.GetStringOutput("serverless_project_id")
		networkProjectID := bqt.GetStringOutput("network_project_id")
		connectorID := bqt.GetStringOutput("connector_id")
		saEmail := bqt.GetStringOutput("service_account_email")

		serverlessProjectNumber := bqt.GetStringOutput("serverless_project_number")
		securityProjectID := bqt.GetStringOutput("security_project_id")
		networkName := bqt.GetStringOutput("service_vpc_name")
		servicePerimeterLink := fmt.Sprintf("accessPolicies/%s/servicePerimeters/%s", policyID, bqt.GetStringOutput("restricted_service_perimeter_name"))
		accessLevel := fmt.Sprintf("accessPolicies/%s/accessLevels/%s", policyID, bqt.GetStringOutput("restricted_access_level_name"))

		// VPC-SC Tests
		servicePerimeter := gcloud.Runf(t, "access-context-manager perimeters describe %s --policy %s", servicePerimeterLink, policyID)
		assert.Equal(servicePerimeterLink, servicePerimeter.Get("name").String(), fmt.Sprintf("service perimeter %s should exist", servicePerimeterLink))
		listLevels := utils.GetResultStrSlice(servicePerimeter.Get("status.accessLevels").Array())
		assert.Contains(listLevels, accessLevel, fmt.Sprintf("service perimeter %s should have access level %s", servicePerimeterLink, accessLevel))
		listServices := utils.GetResultStrSlice(servicePerimeter.Get("status.restrictedServices").Array())
		assert.Subset(listServices, restrictedServices, fmt.Sprintf("service perimeter %s should restrict %v", servicePerimeterLink, restrictedServices))

		// Network test
		opCloudRun := gcloud.Runf(t, "compute networks describe %s --project=%s", networkName, networkProjectID)
		assert.Equal("GLOBAL", opCloudRun.Get("routingConfig.routingMode").String(), fmt.Sprint("Routing Mode should be GLOBAL."))

		// Sub-network test
		subnetName := bqt.GetStringOutput("service_vpc_subnet_name")
		subNetRange := "10.0.0.0/28"
		subnet := gcloud.Runf(t, "compute networks subnets describe %s --region %s --project %s", subnetName, location, networkProjectID)
		assert.Equal(subnetName, subnet.Get("name").String(), fmt.Sprintf("subnet %s should exist", subnetName))
		assert.Equal(subNetRange, subnet.Get("ipCidrRange").String(), fmt.Sprintf("IP CIDR range %s should be", subNetRange))

		// Firewall - Deny all egress test
		denyAllEgressName := "fw-e-shared-restricted-65535-e-d-all-all-all"
		denyAllEgressRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", denyAllEgressName, networkProjectID)
		assert.Equal(denyAllEgressName, denyAllEgressRule.Get("name").String(), fmt.Sprintf("firewall rule %s should exist", denyAllEgressName))
		assert.Equal("EGRESS", denyAllEgressRule.Get("direction").String(), fmt.Sprintf("firewall rule %s direction should be EGRESS", denyAllEgressName))
		assert.True(denyAllEgressRule.Get("logConfig.enable").Bool(), fmt.Sprintf("firewall rule %s should have log configuration enabled", denyAllEgressName))
		assert.Equal("0.0.0.0/0", denyAllEgressRule.Get("destinationRanges").Array()[0].String(), fmt.Sprintf("firewall rule %s destination ranges should be 0.0.0.0/0", denyAllEgressName))
		assert.Equal(1, len(denyAllEgressRule.Get("denied").Array()), fmt.Sprintf("firewall rule %s should have only one denied", denyAllEgressName))
		assert.Equal(1, len(denyAllEgressRule.Get("denied.0").Map()), fmt.Sprintf("firewall rule %s should have only one denied only with no ports", denyAllEgressName))
		assert.Equal("all", denyAllEgressRule.Get("denied.0.IPProtocol").String(), fmt.Sprintf("firewall rule %s should deny all protocols", denyAllEgressName))

		// Firewall - Allow Restricted APIs
		allowApiEgressName := "fw-e-shared-restricted-65534-e-a-allow-google-apis-all-tcp-443"
		allowApiEgressRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", allowApiEgressName, networkProjectID)
		assert.Equal(allowApiEgressName, allowApiEgressRule.Get("name").String(), fmt.Sprintf("firewall rule %s should exist", allowApiEgressName))
		assert.Equal("EGRESS", allowApiEgressRule.Get("direction").String(), fmt.Sprintf("firewall rule %s direction should be EGRESS", allowApiEgressName))
		assert.True(allowApiEgressRule.Get("logConfig.enable").Bool(), fmt.Sprintf("firewall rule %s should have log configuration enabled", allowApiEgressName))
		assert.Equal("10.3.0.5", allowApiEgressRule.Get("destinationRanges").Array()[0].String(), fmt.Sprintf("firewall rule %s destination ranges should be %s", allowApiEgressName, subNetRange))
		assert.Equal(1, len(allowApiEgressRule.Get("allowed").Array()), fmt.Sprintf("firewall rule %s should have only one allowed", allowApiEgressName))
		assert.Equal(2, len(allowApiEgressRule.Get("allowed.0").Map()), fmt.Sprintf("firewall rule %s should have only one allowed only with protocol end ports", allowApiEgressName))
		assert.Equal("tcp", allowApiEgressRule.Get("allowed.0.IPProtocol").String(), fmt.Sprintf("firewall rule %s should allow tcp protocol", allowApiEgressName))
		assert.Equal(1, len(allowApiEgressRule.Get("allowed.0.ports").Array()), fmt.Sprintf("firewall rule %s should allow only one port", allowApiEgressName))
		assert.Equal("443", allowApiEgressRule.Get("allowed.0.ports.0").String(), fmt.Sprintf("firewall rule %s should allow port 443", allowApiEgressName))

		// VPC test
		connectorName := "con-secure-cloud-function"
		expectedSubnet := fmt.Sprintf("sb-restricted-%s", location)
		expectedMachineType := "e2-micro"
		opVPCConnector := gcloud.Runf(t, "compute networks vpc-access connectors describe %s --region=%s --project=%s", connectorName, location, projectID)
		assert.Equal(connectorID, opVPCConnector.Get("name").String(), fmt.Sprintf("Should have same id: %s", connectorID))
		assert.Equal(expectedSubnet, opVPCConnector.Get("subnet.name").String(), fmt.Sprintf("Should have same subnetwork: %s", expectedSubnet))
		assert.Equal(expectedMachineType, opVPCConnector.Get("machineType").String(), fmt.Sprintf("Should have same machineType: %s", expectedMachineType))
		assert.Equal("7", opVPCConnector.Get("maxInstances").String(), "Should have maxInstances equals to 7")
		assert.Equal("2", opVPCConnector.Get("minInstances").String(), "Should have minInstances equals to 2")
		assert.Equal("700", opVPCConnector.Get("maxThroughput").String(), "Should have maxThroughput equals to 700")
		assert.Equal("200", opVPCConnector.Get("minThroughput").String(), "Should have minThroughput equals to 200")

		// Org Policy test
		for _, orgPolicy := range []struct {
			constraint    string
			allowedValues string
		}{
			{
				constraint:    "constraints/cloudfunctions.allowedIngressSettings",
				allowedValues: "ALLOW_INTERNAL_ONLY",
			},
			{
				constraint:    "cloudfunctions.allowedVpcConnectorEgressSettings",
				allowedValues: "ALL_TRAFFIC",
			},
			{
				constraint:    "constraints/run.allowedVPCEgress",
				allowedValues: "private-ranges-only",
			},
			{
				constraint:    "constraints/run.allowedIngress",
				allowedValues: "is:internal-and-cloud-load-balancing",
			},
		} {
			orgArgs := gcloud.WithCommonArgs([]string{"--flatten", "listPolicy.allowedValues[]", "--format", "json"})
			opOrgPolicies := gcloud.Run(t, fmt.Sprintf("resource-manager org-policies describe %s --project=%s", orgPolicy.constraint, projectID), orgArgs).Array()
			assert.Equal(orgPolicy.allowedValues, opOrgPolicies[0].Get("listPolicy.allowedValues").String(), fmt.Sprintf("Constraint %s should have policy %s", orgPolicy.constraint, orgPolicy.allowedValues))
		}

		// Service account test
		serviceAccountName := "sa-cloud-function"
		serviceAccountEmail := fmt.Sprintf("%s@%s.iam.gserviceaccount.com", serviceAccountName, projectID)
		serviceAccountID := fmt.Sprintf("projects/%s/serviceAccounts/%s", projectID, serviceAccountEmail)
		serviceAccount := gcloud.Runf(t, "iam service-accounts describe %s", serviceAccountEmail)
		assert.Equal(serviceAccountID, serviceAccount.Get("name").String(), fmt.Sprintf("Service Account %s should exist", serviceAccountID))

		// Workerpool test
		workerPoolName := "workerpool"
		opWorkerPool := gcloud.Runf(t, "builds worker-pools describe %s --project %s --region %s", workerPoolName, projectID, location)
		assert.Equal("NO_PUBLIC_EGRESS", opWorkerPool.Get("privatePoolV1Config.networkConfig.egressOption").String(), "Private Pool config should have NO_PUBLIC_EGRESS")

		// Cloud Function test
		function_cmd := gcloud.Runf(t, "functions describe %s --project %s --gen2 --region %s", name, projectID, location)
		assert.Equal("ACTIVE", function_cmd.Get("state").String(), "Should be ACTIVE. Cloud Function is not successfully deployed.")
		assert.Equal(connectorID, function_cmd.Get("serviceConfig.vpcConnector").String(), fmt.Sprintf("VPC Connector should be %s. Connector was not set.", connectorID))
		assert.Equal("PRIVATE_RANGES_ONLY", function_cmd.Get("serviceConfig.vpcConnectorEgressSettings").String(), "Egress setting should be PRIVATE_RANGES_ONLY.")
		assert.Equal("ALLOW_INTERNAL_AND_GCLB", function_cmd.Get("serviceConfig.ingressSettings").String(), "Ingress setting should be ALLOW_INTERNAL_AND_GCLB.")
		assert.Equal(saEmail, function_cmd.Get("serviceConfig.serviceAccountEmail").String(), fmt.Sprintf("Cloud Function should use the service account %s.", saEmail))
		assert.Contains(function_cmd.Get("eventTrigger.eventType").String(), "google.cloud.audit.log.v1.written", "Event Trigger is not based on Audit Logs. Check the EventType configuration.")

		// Cloud Function Storage Bucket test
		bucketSrcBucket := fmt.Sprintf("gcf-v2-sources-%s-%s", serverlessProjectNumber, location)
		gcloudArgsBucketCF := gcloud.WithCommonArgs([]string{"--project", projectID, "--json"})
		opSrcBucket := gcloud.Run(t, fmt.Sprintf("alpha storage ls --buckets gs://%s", bucketSrcBucket), gcloudArgsBucketCF).Array()
		cfKMSKey := fmt.Sprintf("projects/%s/locations/%s/keyRings/krg-secure-cloud-function/cryptoKeys/key-secure-cloud-function", securityProjectID, location)
		assert.Equal(cfKMSKey, opSrcBucket[0].Get("metadata.encryption.defaultKmsKeyName").String(), fmt.Sprintf("Should have same KMS key: %s", cfKMSKey))
		assert.Equal("true", opSrcBucket[0].Get("metadata.iamConfiguration.bucketPolicyOnly.enabled").String(), "Should have Bucket Policy Only enabled.")

		// Cloud Function Artifact Registry
		arCF := fmt.Sprintf("rep-cloud-function-%s", name)
		opAR := gcloud.Runf(t, "artifacts repositories describe %s --project %s --location %s --format json", arCF, projectID, location)
		assert.Equal(cfKMSKey, opAR.Get("kmsKeyName").String(), fmt.Sprintf("Should have KMS Key: %s", cfKMSKey))
		assert.Equal("DOCKER", opAR.Get("format").String(), "Should have type: DOCKER")

		// Cloud Function EventArc
		opEventArc := gcloud.Runf(t, "eventarc google-channels describe --project %s --location %s --format json", projectID, location)
		assert.Equal(cfKMSKey, opEventArc.Get("cryptoKeyName").String(), fmt.Sprintf("Should have KMS Key: %s", cfKMSKey))

		// Bigquery test
		bqKmsKey := bqt.GetStringOutput("bigquery_kms_key")
		opDataset := gcloud.Runf(t, "alpha bq tables describe tbl_test --dataset dst_secure_cloud_function --project %s", projectID)
		fullTablePath := fmt.Sprintf("%s:dst_secure_cloud_function.tbl_test", projectID)
		assert.Equal(fullTablePath, opDataset.Get("id").String(), fmt.Sprintf("Should have same id: %s", fullTablePath))
		assert.Equal(location, opDataset.Get("location").String(), fmt.Sprintf("Should have same location: %s", location))
		assert.Equal(bqKmsKey, opDataset.Get("encryptionConfiguration.kmsKeyName").String(), fmt.Sprintf("Should have the KMS Key: %s", bqKmsKey))
	})
	bqt.Test()
}
