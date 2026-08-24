# Workload Identity Federation for GitHub Actions.
#
# Lets GitHub Actions workflows in KSiig/homelab and KSiig/tilbudstracker
# authenticate to GCP without a long-lived service account key.

resource "google_project_service" "iam_credentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Workload identity pool for GitHub Actions OIDC"
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions"
  description                        = "OIDC provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "assertion.repository_owner == \"KSiig\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  depends_on = [google_project_service.iam_credentials]
}

resource "google_service_account" "github_actions" {
  account_id   = "github-actions"
  display_name = "GitHub Actions"
  description  = "Service account impersonated by GitHub Actions via Workload Identity Federation"
}

locals {
  github_actions_roles = [
    "roles/cloudfunctions.developer",
    "roles/iam.serviceAccountUser",
    "roles/storage.admin",
    "roles/cloudscheduler.admin",
    "roles/secretmanager.admin",
    "roles/billing.viewer",
  ]
}

resource "google_project_iam_member" "github_actions" {
  for_each = toset(local.github_actions_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_service_account_iam_binding" "github_actions_workload_identity" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/KSiig/homelab",
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/KSiig/tilbudstracker",
  ]
}

output "wif_provider" {
  description = "Full resource name of the Workload Identity Pool Provider (use as GCP_WIF_PROVIDER GitHub secret)"
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}

output "service_account_email" {
  description = "Email of the GitHub Actions service account (use as GCP_SA_EMAIL GitHub secret)"
  value       = google_service_account.github_actions.email
}
