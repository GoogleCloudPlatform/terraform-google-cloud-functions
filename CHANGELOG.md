# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).
This changelog is generated automatically based on [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## [0.7.0](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/compare/v0.6.0...v0.7.0) (2025-01-09)


### ⚠ BREAKING CHANGES

* **deps:** Update Terraform terraform-google-modules/cloud-storage/google to v8 ([#147](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/147))

### Bug Fixes

* **deps:** Update Terraform terraform-google-modules/cloud-storage/google to v8 ([#147](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/147)) ([3b38f4b](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/3b38f4baf8c855780b17c92affb6f0b9c4e4deac))

## [0.6.0](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/compare/v0.5.0...v0.6.0) (2024-06-26)


### Features

* add build service account argument ([#130](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/130)) ([d17cfa7](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/d17cfa7f14bbe31c2ddb6aa882a12a83cee4de56))


### Bug Fixes

* **deps:** Update Terraform GoogleCloudPlatform/cloud-run/google to ~&gt; 0.12.0 ([#128](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/128)) ([74de747](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/74de7477a07d93452518251a95a5254953fa6f71))

## [0.5.0](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/compare/v0.4.1...v0.5.0) (2024-05-22)


### ⚠ BREAKING CHANGES

* **deps:** Update Terraform terraform-google-modules/cloud-storage/google to v6 ([#123](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/123))
* **TPG>=5.12:** Update Terraform GoogleCloudPlatform/cloud-run/google to ~> 0.11.0 ([#125](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/125))
* **deps:** Update Terraform terraform-google-modules/network/google to v9 ([#99](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/99))
* **deps:** Update Terraform terraform-google-modules/pubsub/google to v6 ([#100](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/100))
* **deps:** Update Terraform terraform-google-modules/cloud-storage/google to v5 ([#98](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/98))

### Features

* Add available_cpu to service_config ([#65](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/65)) ([178cb1d](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/178cb1d4def363c3c6984bb5d854d7823a97e867))
* **deps:** Update Terraform Google Provider to &gt;= 4.48, &lt; 6 ([#117](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/117)) ([8836a87](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/8836a8794d0d2934c3ddab2e64c14c87d3e90c4e))
* updated the role for CF Gen 2 ([#88](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/88)) ([33e9efa](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/33e9efa1c2cea37cc64ea4f44aa6a4ce3568c259))


### Bug Fixes

* **deps:** Allow Terraform Google Provider to v5 ([#74](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/74)) ([38e7ed2](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/38e7ed2e3fb6770164f28259dbc62204ea2fd483))
* **deps:** Update Terraform GoogleCloudPlatform/cloud-run/google to ~&gt; 0.10.0 ([#96](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/96)) ([d06a9ad](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/d06a9ad5070e3daf29687d7accac990bb2b08352))
* **deps:** Update Terraform terraform-google-modules/cloud-storage/google to v5 ([#98](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/98)) ([fb92c16](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/fb92c16dcec51a66a729e3446a2ba0401c8f73a7))
* **deps:** Update Terraform terraform-google-modules/cloud-storage/google to v6 ([#123](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/123)) ([459c88f](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/459c88ff2348f6c5d0275d233c8b27f051d3b992))
* **deps:** Update Terraform terraform-google-modules/network/google to v9 ([#99](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/99)) ([2188cec](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/2188cec9d754c442ccfadb8f54b77935173a99a3))
* **deps:** Update Terraform terraform-google-modules/pubsub/google to v6 ([#100](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/100)) ([bc4fe56](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/bc4fe56900dd95e48f2b7a1236869db6e32a18f7))
* remove duplicate group_cloud_run_developer ([#113](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/113)) ([69a64c0](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/69a64c0c96778f70f398d6a5eede0f4f4b2615ec))
* **TPG>=5.12:** Update Terraform GoogleCloudPlatform/cloud-run/google to ~&gt; 0.11.0 ([#125](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/125)) ([0c64ca2](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/0c64ca2e9c2a2883f9e87131fa05b1ad298be08f))

## [0.4.1](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/compare/v0.4.0...v0.4.1) (2023-07-27)


### Bug Fixes

* Change Secure Web Proxy creation to use terraform resource instead of gcloud command ([#52](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/52)) ([f167312](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/f1673128280ec1b447a1aafbb55319e380c142b9))

## [0.4.0](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/compare/v0.3.0...v0.4.0) (2023-07-17)


### Features

* add instructions to deploy the Secure Cloud Function on top of the Terraform Example Foundation v3.0.0 ([#37](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/37)) ([f458a1c](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/f458a1c965397158181151ca7cac0527d1395476))
* Adding Secure Web Proxy to examples ([#43](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/43)) ([99f9bfe](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/99f9bfe7eb4f358d4efbd1f8660ddbe14b90e932))
* Adds example of secure-cloud-function triggered by BigQuery ([#26](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/26)) ([2ac3d91](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/2ac3d91cab2895006c2e6afed7bceab8ecd1a168))
* Adds Secure Web Proxy private module ([#34](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/34)) ([17717c1](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/17717c1e10ee3d3691a543f6df4d3c564f1f3c0e))
* adds secure-cloud-function + cloud sql example ([#30](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/30)) ([8d1005c](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/8d1005c2fec2227e4e839358cc175b3448327d8a))
* support upstream serverless module attribute changes ([#55](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/55)) ([749071a](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/749071ab124833654f98e093418693d1a7059bb5))


### Bug Fixes

* Add instructions on Bigquery example ([#57](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/57)) ([42bf7a6](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/42bf7a6f5a8c4b6d6d77079a70c0ce561188fd52))
* Add instructions on Internal server example ([#56](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/56)) ([a8c6b68](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/a8c6b68e4785a7e55298b3d28e38c6d7dc48455f))
* Add test instructions for foundation deploy ([#61](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/61)) ([ff9b9b4](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/ff9b9b4f7d17227f368f60e7423df31aa9139146))
* adds public source/version in sub-modules at READMEs ([#62](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/62)) ([0d84594](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/0d84594110afcf5fc5195e7cfe80fc0f4445018e))
* Changes connector egress setting and org policies ([#47](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/47)) ([94158d9](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/94158d95371c052df439f312bea94be6a5984631))
* Cloud Sql example instructions ([#58](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/58)) ([185b7ef](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/185b7ef7adc1766667d72c9a4065c2276d6656c0))
* Fix foundation deploy instructions ([#59](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/59)) ([a95daa4](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/a95daa4e3a4861c65842c6e3c2267d769030bb20))
* Fix README in Cloud SQL Example ([#38](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/38)) ([749e871](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/749e871da42d4b69140d68992a971809d474e514))
* Fixes roles and apis on modules readmes ([#39](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/39)) ([787eb14](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/787eb14bfe34f9c51160f0451f5017e39b4cca67))
* Renames secure-cloud-serverless-security module to secure-cloud-function-security ([#41](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/41)) ([b7cfd69](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/b7cfd693ed43cffb2ae7603f7e06d3f6125b649c))
* Secure Web Proxy fix ([#46](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/46)) ([1743c51](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/1743c514e3c7b74c79114c2ada5cc2dd6840a1fa))

## [0.3.0](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/compare/v0.2.0...v0.3.0) (2023-05-17)


### Features

* adds first version of secure-serverless-security module ([#21](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/21)) ([b7e9787](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/b7e97877bdbd47209a2b55f1320d5d18e7157197))
* adds secure cloud-function-core sub-module ([#20](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/20)) ([c9c197f](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/c9c197f9885dc2efed650c16521689eea04411c4))
* adds secure-cloud-function sub-module ([#22](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/22)) ([048efa0](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/048efa00dafa6e59eac6d1633043b7476704ae98))


### Bug Fixes

* **deps:** update terraform terraform-google-modules/cloud-storage/google to v4 ([#25](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/25)) ([e3d2ae8](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/e3d2ae8b6e85b54538c58265bf0535221687bed2))

## [0.2.0](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/compare/v0.1.0...v0.2.0) (2023-02-21)


### Features

* optional feature for variables and test cases ([#6](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/issues/6)) ([bd17644](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/bd176444025403a4d184a4099c6c4b26fcf43818))

## 0.1.0 (2023-02-03)


### Features

* added iam membership ([393b404](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/393b404bd39294533b873689874fc43964cec9c5))
* cleanup and docs ([6ff316e](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/6ff316ef8c1fd3230246091e984e1a8ca3a188a0))
* initial commit ([94ef748](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/94ef748b132d1cad8b0928b040621cf901edab7f))
* updated variables for iam ([381b07c](https://github.com/GoogleCloudPlatform/terraform-google-cloud-functions/commit/381b07c5dfee60475e13576b8c7d189bd61bad4f))

## [0.1.0](https://github.com/terraform-google-modules/terraform-google-cloud-functions/releases/tag/v0.1.0) - 20XX-YY-ZZ

### Features

- Initial release

[0.1.0]: https://github.com/terraform-google-modules/terraform-google-cloud-functions/releases/tag/v0.1.0
