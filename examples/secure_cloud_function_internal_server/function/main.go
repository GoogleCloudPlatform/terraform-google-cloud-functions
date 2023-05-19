package helloworld

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

func init() {
	functions.HTTP("helloHTTP", helloHTTP)
}

func helloHTTP(w http.ResponseWriter, r *http.Request) {
	ipAddress := os.Getenv("TARGET_IP")
	if ipAddress == "" {
		log.Println("TARGET_IP environment variable not set")
		http.Error(w, "TARGET_IP not set", http.StatusInternalServerError)
		return
	}

	url := fmt.Sprintf("http://%s:8000/index.html", ipAddress)

	// Send GET request to the server
	response, err := http.Get(url)
	if err != nil {
		log.Printf("Failed to send GET request: %s\n", err)
		http.Error(w, "Failed to send GET request", http.StatusInternalServerError)
		return
	}
	defer response.Body.Close()

	// Read the response body
	content, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Printf("Failed to read response body: %s\n", err)
		http.Error(w, "Failed to read response body", http.StatusInternalServerError)
		return
	}

	// Log the content
	log.Printf("Message returned from internal server: %s\n", string(content))

	// Write the content to the response
	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(content))
}
