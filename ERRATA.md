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

For this version, the Cloud Run constraints are being enforced instead of the Cloud Functions constraints during the deploy of Secured Cloud Function. This behaviour happens because Cloud Function Gen2 is using Cloud Run as the execution platform.

#### Secure Web Proxy

The [Secure Web Proxy](https://cloud.google.com/secure-web-proxy) is used to allow Cloud Functions build process to download code dependencies from external repositories in the internet. It should only be available during the build process execution.

The Secure Web Proxy should be part of a defined deployment process that guarantees that it will be enabled only during the time necessary for the Cloud Build builds execution. The management of the Secure Web Proxy should be part of the build process instead of being running the whole time.

#### Notes

Please refer to [this documentation](https://github.com/renato-rudnicki/terraform-google-cloud-functions/blob/errata/docs/secure-web-proxy.md) for more details about how manually delete the Secure Web Proxy.

