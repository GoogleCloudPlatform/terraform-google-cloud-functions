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

package cloudsql

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net"
	"os"

	// Pre importing this dependency because it has a redirect that doesn't work with Secure Web Proxy
	_ "golang.org/x/sync/errgroup"

	"cloud.google.com/go/cloudsqlconn"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/go-sql-driver/mysql"
)

func init() {
	functions.CloudEvent("HelloCloudFunction", connect)
}

func connect(ctx context.Context, e event.Event) error {
	instanceProjectID := os.Getenv("INSTANCE_PROJECT_ID")
	instanceUser := os.Getenv("INSTANCE_USER")
	instancePWD := os.Getenv("INSTANCE_PWD")
	instanceLocation := os.Getenv("INSTANCE_LOCATION")
	instanceName := os.Getenv("INSTANCE_NAME")
	databaseName := os.Getenv("DATABASE_NAME")

	d, err := cloudsqlconn.NewDialer(
		ctx,
		cloudsqlconn.WithDefaultDialOptions(
			cloudsqlconn.WithPrivateIP(),
		),
	)
	if err != nil {
		log.Fatal(err)
		fmt.Errorf("Error creating new Dialer", err)
	}

	instanceConnectionName := fmt.Sprintf("%s:%s:%s", instanceProjectID, instanceLocation, instanceName)

	fmt.Println("Registering Driver.")
	mysql.RegisterDialContext("cloudsqlconn",
		func(ctx context.Context, addr string) (net.Conn, error) {
			return d.Dial(ctx, instanceConnectionName)
		})

	fmt.Println("Open connection.")
	db, err := sql.Open(
		"mysql",
		fmt.Sprintf("%s:%s@cloudsqlconn(%s)/%s", instanceUser, instancePWD, instanceConnectionName, databaseName),
	)
	if err != nil {
		log.Fatal(err)
		fmt.Errorf("Error connecting to data base.", err)
	}
	err = db.Ping()
	if err != nil {
		log.Fatal(err)
		fmt.Errorf("Error during ping.", err)
	}

	var (
		id          int
		name        string
		performance string
	)

	fmt.Println("Select from table.")
	res, err := db.Query("SELECT * FROM characters")

	for res.Next() {
		err := res.Scan(&id, &name, &performance)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(fmt.Sprintf("%v: %s: %s", id, name, performance))
	}

	return err
}
