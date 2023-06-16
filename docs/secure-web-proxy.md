# Secure Web Proxy usage in the Secure Cloud Function

A Secure Web Proxy is a cloud first service that helps you secure egress web traffic (HTTP/S). It acts as an intermediary between users and the websites they want to access, ensuring the security, control and optimization of Internet access. See the  [Secure Web Proxy](https://cloud.google.com/secure-web-proxy/docs/overview) documentation for additional information.

In the context of the Secure Cloud Function the Secure Web Proxy is used  to allow the Cloud Build build that is creating the image that will be used to deploy the Cloud Function to access the internet and download the dependencies of the source code of the function.
Cloud Build is using a private worker pool where the instances do not have an external IP. This configuration does not allow direct access to the internet. Redirecting the Cloud Build http request through the Secure Web Proxy allows this to happen in a controlled and safe way.

The Secure Web Proxy is needed to securely build your Cloud Functions. But the Secure Web Proxy  is not needed at run-time.

## Pricing

See detailed  [Secure Web Proxy pricing](https://cloud.google.com/secure-web-proxy/pricing) information in the official documentation.

## Deleting the Secure Web proxy after deploying the examples

To prevent additional charges related to the Secure Web Proxy after deploying the examples in this repository the Secure Web Proxy can be deleted using the gcloud command as by the following instructions:

For the BigQuery and Internal Web Server examples use:

```bash
export REGION="us-west1"
```

For the Cloud SQL example use:

```bash
export REGION="us-central1"
```

1. First need to delete the SWP itself, using the following gcloud command (we assume this command will be run from the directory of the example that was deployed):

```bash
export PROJECT_ID=$(terraform output -raw network_project_id)

gcloud network-services gateways delete secure-web-proxy --location=${REGION} --project=${PROJECT_ID}
```

2. There is also an auto generated resource, a router, that needs to be deleted.
To delete the auto-generated router, use the following instructions:

```bash
# get the network number
export NETWORK_NUMBER=$(gcloud compute networks describe projects/${PROJECT_ID}/regions/${REGION}/networks/vpc-secure-cloud-function --format='value(id)')

# delete the auto generated router
gcloud compute routers delete swg-autogen-router-${NETWORK_NUMBER} --project=${PROJECT_ID}
```

More information on how to manually create and delete secure web proxy in Google Cloud Platform is available in the official documentation. See the [Deploy a Secure Web Proxy instance](https://cloud.google.com/secure-web-proxy/docs/quickstart#clean-up) instruction.
