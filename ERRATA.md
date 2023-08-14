# Errata Summary

This is an overview of the delta between the example Secure Serverless Functions architecture repository and the [Serverless architecture using Cloud Functions guide](https://cloud.google.com/architecture/serverless-functions-blueprint), including code discrepancies and notes on future automation. This document will be updated as new code is merged.

## [0.4.1](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/releases/tag/v0.4.1)

### Blueprint Configuration 

#### Constraints

The constraints below are using opinionated values instead of the constraints default values:

- `constraints/cloudfunctions.allowedIngressSettings`. The constraint default value is `ALLOW_ALL` and in the secure-cloud-function-security module we are using `ALLOW_INTERNAL_ONLY` as default.
- `constraints/cloudfunctions.requireVPCConnector`. The constraint default value is `enforce:null` and in the secure-cloud-function-security module we are using `enforce:true` as default.
- `constraints/cloudfunctions.allowedVpcConnectorEgressSettings`. The constraint default value is `PRIVATE_RANGES_ONLY` and in the secure-cloud-function-security module we are using `ALL_TRAFFIC` as default.
- `constraints/run.allowedIngress`. The constraint default value is "all" and in the secure-cloud-function-security module we are using `is:internal-and-cloud-load-balancing`
not the corresponding Google Cloud Functions constraints.

#### Notes 
The Secure Web Proxy should only be available during the build process execution and it should be part of a defined deployment process that guarantees that the Secure Web Proxy will be enabled only during the time necessary for the Cloud Build builds execution instead of the whole time. The build process execution should be defined by the build team and not by the example.

