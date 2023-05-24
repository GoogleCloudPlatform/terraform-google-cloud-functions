/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


resource "google_compute_subnetwork" "swp_subnetwork_proxy" {
  name          = "sb-swp-${var.region}"
  ip_cidr_range = "10.129.0.0/23"
  project       = var.project_id
  region        = var.region
  network       = var.network_id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

module "swp_firewall_rule" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "~> 7.0"
  project_id   = var.project_id
  network_name = var.network_id

  rules = [{
    name        = "fw-allow-tcp-443-egress-to-secure-web-proxy"
    description = "Allow Cloud Build to connect in Secure Web Proxy"
    direction   = "EGRESS"
    priority    = 100
    ranges      = ["10.129.0.0/23", "10.0.0.0/28"]
    source_tags = []
    allow = [{
      protocol = "tcp"
      ports    = ["443"]
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}

resource "google_compute_global_address" "private_ip_allocation" {
  name          = "swp-cloud-function-internal-connection"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "private_service_connect" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_allocation.name]

  depends_on = [
    google_compute_global_address.private_ip_allocation
  ]
}

resource "google_certificate_manager_certificate" "swp_certificate" {
  name        = "swp-certificate"
  description = "Secure Web Proxy provided certificate."
  project     = var.project_id
  location    = var.region
  self_managed {
    pem_private_key = file("${var.certificate_path}/key.pem")
    pem_certificate = file("${var.certificate_path}/cert.pem")
  }
}

resource "google_network_security_gateway_security_policy" "swp_security_policy" {
  provider    = google-beta
  name        = "swp-security-policy"
  project     = var.project_id
  location    = var.region
  description = "Secure Web Proxy security policy."
}

resource "google_network_security_url_lists" "swp_url_lists" {
  provider    = google-beta
  name        = "swp-url-lists"
  project     = var.project_id
  location    = var.region
  description = "Secure Web Proxy list of allowed URLs."
  values      = var.url_lists
}

resource "google_network_security_gateway_security_policy_rule" "swp_security_policy_rule" {
  provider                = google-beta
  name                    = "swp-security-policy-rule"
  project                 = var.project_id
  location                = var.region
  gateway_security_policy = google_network_security_gateway_security_policy.swp_security_policy.name
  enabled                 = true
  description             = "Secure Web Proxy security policy rule."
  priority                = 1
  session_matcher         = "inUrlList(host(), '${google_network_security_url_lists.swp_url_lists.id}')"
  tls_inspection_enabled  = false
  basic_profile           = "ALLOW"

  depends_on = [
    google_network_security_url_lists.swp_url_lists,
    google_network_security_gateway_security_policy.swp_security_policy
  ]
}

resource "null_resource" "swp_generate_gateway_config" {
  provisioner "local-exec" {
    command = <<EOF
      cat << EOF > gateway.yaml
      name: projects/${var.project_id}/locations/${var.region}/gateways/secure-web-proxy
      type: SECURE_WEB_GATEWAY
      addresses: ["10.0.0.10"]
      ports: [443]
      certificateUrls: ["${google_certificate_manager_certificate.swp_certificate.id}"]
      gatewaySecurityPolicy: ${google_network_security_gateway_security_policy.swp_security_policy.id}
      network: ${var.network_id}
      subnetwork: projects/${var.project_id}/regions/${var.region}/subnetworks/sb-restricted-${var.region}
      scope: samplescope
    EOF
  }

  depends_on = [
    google_certificate_manager_certificate.swp_certificate,
    google_network_security_gateway_security_policy.swp_security_policy
  ]
}

resource "null_resource" "swp_deploy" {

  triggers = {
    project_id = var.project_id
    location   = var.region
    network_id = var.network_id
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOF
      gcloud alpha network-services gateways import secure-web-proxy \
        --source=gateway.yaml \
        --location=${var.region} \
        --project=${var.project_id}
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      gcloud network-services gateways delete secure-web-proxy \
        --location=${self.triggers.location} \
        --project=${self.triggers.project_id} \
        --quiet

      NETWORK_NUMBER=$(gcloud compute networks describe ${self.triggers.network_id} --project=${self.triggers.project_id} --format='value(id)')
      gcloud compute routers delete swg-autogen-router-$NETWORK_NUMBER \
        --region=${self.triggers.location} \
        --project=${self.triggers.project_id} \
        --quiet
    EOF
  }

  depends_on = [
    google_certificate_manager_certificate.swp_certificate,
    google_compute_subnetwork.swp_subnetwork_proxy,
    google_network_security_gateway_security_policy.swp_security_policy,
    google_network_security_url_lists.swp_url_lists,
    google_network_security_gateway_security_policy_rule.swp_security_policy_rule,
    null_resource.swp_generate_gateway_config
  ]
}

resource "time_sleep" "wait_secure_web_proxy" {
  create_duration  = "3m"
  destroy_duration = "1m"

  depends_on = [
    null_resource.swp_deploy
  ]
}
