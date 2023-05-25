// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// [START cloudrun_helloworld_service]
// [START run_helloworld_service]

// Sample run-helloworld is a minimal Cloud Run service.
package helloworld

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"cloud.google.com/go/storage"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/compute/v1"
	"google.golang.org/api/iterator"
)

func init() {
	functions.CloudEvent("HelloCloudFunction", helloPubSub)
}

// MessagePublishedData contains the full Pub/Sub message
// See the documentation for more details:
// https://cloud.google.com/eventarc/docs/cloudevents#pubsub
type MessagePublishedData struct {
	Message PubSubMessage
}

// PubSubMessage is the payload of a Pub/Sub event.
// See the documentation for more details:
// https://cloud.google.com/pubsub/docs/reference/rest/v1/PubsubMessage
type PubSubMessage struct {
	Data []byte `json:"data"`
}

func helloPubSub(ctx context.Context, e event.Event) error {
	name := os.Getenv("NAME")
	if name == "" {
		name = "World"
	}
	regions, err := listComputeRegions()
	if err != nil {
		log.Printf("Error listing compute regions: %s.", err.Error())
		fmt.Errorf(err.Error())
	}
	log.Printf("Regions: %v!\n", regions)
	buckets, err := listBuckets()
	if err != nil {
		log.Printf("Error listing project buckets: %s.", err.Error())
		fmt.Errorf(err.Error())
	}

	log.Printf("Buckets: %v!\n", buckets)
	return nil
}

// [END run_helloworld_service]

// [START storage_list_buckets]
// listBuckets lists buckets in the project.
func listBuckets() ([]string, error) {
	projectID := os.Getenv("PROJECT_ID")
	ctx := context.Background()
	log.Println("Creating Client for Storage.")
	client, err := storage.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("storage.NewClient: %v", err)
	}
	defer client.Close()

	ctx, cancel := context.WithTimeout(ctx, time.Second*30)
	defer cancel()

	var buckets []string
	log.Println("Getting buckets in project.")
	it := client.Buckets(ctx, projectID)
	for {
		battrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}
		buckets = append(buckets, battrs.Name)
	}
	return buckets, nil
}

func listComputeRegions() ([]string, error) {
	ctx := context.Background()

	log.Println("Creating Default Client for Compute client.")
	c, err := google.DefaultClient(ctx)
	if err != nil {
		log.Fatal(err)
	}

	log.Println("Creating service for Compute client.")
	computeService, err := compute.New(c)
	if err != nil {
		log.Fatal(err)
	}

	// Project ID for this request.
	project := os.Getenv("PROJECT_ID")
	var regions []string
	log.Println("Getting compute regions.")
	req := computeService.Regions.List(project)
	if err := req.Pages(ctx, func(page *compute.RegionList) error {
		for _, region := range page.Items {
			// TODO: Change code below to process each `region` resource:
			regions = append(regions, region.Name)
		}
		return nil
	}); err != nil {
		log.Fatal(err)
		return nil, err
	}
	return regions, nil
}

// [END storage_list_buckets]

// [END cloudrun_helloworld_service]
