# Errata Summary

## [0.2.0](https://github.com/GoogleCloudPlatform/terraform-google-secured-data-warehouse/releases/tag/v0.2.0)

This is an overview of the delta between the example Secure Serverless Functions architecture repository and the [Serverless architecture using Cloud Functions guide](https://cloud.google.com/architecture/serverless-functions-blueprint), including code discrepancies and notes on future automation. This document will be updated as new code is merged.

### Code Discrepancies

#### Constraints
The following constraints are applied by the secure-cloud-function-security module, not following the default values in the official documentation:

For CloudFunction
- "constraints/cloudfunctions.allowedIngressSettings". The constraint default value is "ALLOW_ALL" and in the secure-cloud-function-security module we are using "ALLOW_INTERNAL_ONLY" as default.
- "constraints/cloudfunctions.requireVPCConnector". The constraint default value is "enforce:null" and in the secure-cloud-function-security module we are using "enforce:true" as default.
- "constraints/cloudfunctions.allowedVpcConnectorEgressSettings". The constraint default value is " PRIVATE_RANGES_ONLY" and in the secure-cloud-function-security module we are using "ALL_TRAFFIC" as default.

For CloudRun
-"constraints/run.allowedIngress". The constraint default value is "all" and in the secure-cloud-function-security module we are using "is:internal-and-cloud-load-balancing"

#### Deployment mode
The secure-cloud-function-security module is also used in the secure-foundation deployment mode.

#### Notes 
The Secure Web Proxy should only be available in the build process and it should be part of a deployment process that guarantees it be turned on only as necessary instead of the whole time. This improvement should be in a future release.

