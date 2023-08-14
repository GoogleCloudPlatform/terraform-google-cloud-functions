# Errata Summary

This is an overview of the delta between the example Secure Serverless Functions architecture repository and the [Serverless architecture using Cloud Functions guide](https://cloud.google.com/architecture/serverless-functions-blueprint), including code discrepancies and notes on future automation. This document will be updated as new code is merged.

## [0.4.1](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/releases/tag/v0.4.1)

### Blueprint Configuration 

#### Constraints

The following constraints are being used for this blueprint:

Cloud Functions
- `constraints/cloudfunctions.allowedIngressSettings` 
- `constraints/cloudfunctions.requireVPCConnector`
- `constraints/cloudfunctions.allowedVpcConnectorEgressSettings`

Cloud Run
- `constraints/run.allowedIngress`
- `constraints/run.allowedVPCEgress`

The Cloud Run constraints are taking place over the Cloud Functions constraints. This behaviour happens because the Cloud Run is using Cloud Function Gen2.

#### Secure Web Proxy

The [Secure Web Proxy](https://cloud.google.com/secure-web-proxy) is designed to allow Cloud Function code to search for code dependencies on the internet if required. It should only be available during the build process execution.

The Secure Web Proxy should be part of a defined deployment process that guarantees that it will be enabled only during the time necessary for the Cloud Build builds execution. The management of the Secure Web Proxy should be part of the build process instead of being running the whole time.

#### Notes 

Please refer to [this documentation](https://github.com/renato-rudnicki/terraform-google-cloud-functions/blob/errata/docs/secure-web-proxy.md) for more details about how manually delete the Secure Web Proxy.

