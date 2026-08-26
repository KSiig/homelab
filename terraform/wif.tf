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

  # Restrict by repo, not just owner, so a forked repo under the same owner
  # can't impersonate this SA.
  attribute_condition = <<-EOT
    assertion.repository_owner == "KSiig" &&
    (assertion.repository == "KSiig/homelab" ||
     assertion.repository == "KSiig/tilbudstracker")
  EOT

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
  # Roles granted project-wide to the GitHub Actions SA.
  # NOTE: `roles/iam.serviceAccountUser` is intentionally NOT in this list.
  # Granting it project-wide would let the deployer impersonate *any* SA in
  # the project (Checkov CKV_GCP_41, CodeRabbit high-risk finding). Instead,
  # SA User is granted per-runtime-SA via
  # google_service_account_iam_member.github_actions_runtime_user, scoped to
  # the explicit Cloud Functions runtime SA(s) declared in
  # var.function_runtime_service_accounts.
  github_actions_roles = [
    "roles/cloudfunctions.developer",
    "roles/storage.admin",
    "roles/cloudscheduler.admin",
    "roles/secretmanager.admin",
    # IAM-admin roles: required so the GitHub Actions SA can refresh and
    # manage its own WIF pool, service account, project-IAM bindings, and
    # API enablements on subsequent applies (Plan needs read perms; Apply
    # needs write). Without these, every CI run fails with 403 on
    # iam.workloadIdentityPools.get / iam.serviceAccounts.get.
    # Acceptable for the single-operator homelab; revisit if the project
    # ever gets shared.
    #
    # Both roles are granted because:
    # - roles/iam.workloadIdentityPoolAdmin should include
    #   iam.workloadIdentityPools.get per docs, but project-level grants
    #   don't always seem to propagate for WIF pools (verified earlier:
    #   binding was in place but API still 403'd).
    # - roles/iam.securityAdmin should cover every IAM op including WIF
    #   pool, but in practice also 403'd.
    # Granting both is belt-and-suspenders; one of them should work.
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/iam.securityAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
  ]
  # NOTE: roles/billing.viewer is intentionally NOT granted here.
  # Billing roles can't be bound at project level (GCP restriction);
  # they must be granted on the billing account itself via
  # google_billing_account_iam_member. The GitHub Actions deployer
  # doesn't need billing read access for Function/Storage/Scheduler/
  # Secret deploys, and the budget alert in budget.tf is read at apply
  # time under whoever runs terraform (the bootstrap user, not this SA).
}

resource "google_project_iam_member" "github_actions" {
  for_each = toset(local.github_actions_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Scoped SA User binding on each Cloud Functions runtime SA. With the default
# empty list this creates zero resources; functions PRs will populate the
# variable and the binding will be created at apply time.
resource "google_service_account_iam_member" "github_actions_runtime_user" {
  for_each = toset(var.function_runtime_service_accounts)

  service_account_id = "projects/${var.project_id}/serviceAccounts/${each.value}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_actions.email}"
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
