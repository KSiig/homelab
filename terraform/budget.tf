data "google_billing_account" "account" {
  display_name = "My Billing Account 1"
  open         = true
}

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_billing_budget" "zero_spend_alert" {
  billing_account = data.google_billing_account.account.id
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
