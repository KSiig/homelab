data "google_project" "current" {
  project_id = var.project_id
}

# Grant the GitHub Actions SA roles/billing.viewer on the billing account
# so terraform plan can refresh state of the budget resource below.
# Billing roles can't be bound at project level (GCP restriction); they
# must be granted on the billing account itself.
resource "google_billing_account_iam_member" "github_actions_billing_viewer" {
  billing_account_id = var.billing_account_id
  role               = "roles/billing.viewer"
  member             = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_billing_budget" "zero_spend_alert" {
  billing_account = var.billing_account_id
  display_name    = "Homelab budget alert"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      currency_code = "DKK"
      units         = "100"
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
    spend_basis       = "FORECASTED_SPEND"
  }
}
