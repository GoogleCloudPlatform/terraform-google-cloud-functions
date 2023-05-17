package helloworld

import (
	"fmt"
	"io/ioutil"
	"net/http"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

func init() {
	functions.HTTP("helloHTTP", helloHTTP)
}

func helloHTTP(w http.ResponseWriter, r *http.Request) {
	url := "http://10.0.0.3:8000/index.html"

	// Send GET request to the server
	response, err := http.Get(url)
	if err != nil {
		fmt.Printf("Failed to send GET request: %s\n", err)
		return
	}
	defer response.Body.Close()

	// Read the response body
	content, err := ioutil.ReadAll(response.Body)
	if err != nil {
		fmt.Printf("Failed to read response body: %s\n", err)
		return
	}

	// Print the content
	fmt.Println(string(content))
}
