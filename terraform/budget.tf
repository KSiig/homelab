data "google_billing_account" "account" {
  display_name = "My Billing Account"
  open         = true
}

resource "google_billing_budget" "zero_spend_alert" {
  billing_account = data.google_billing_account.account.id
  display_name    = "Homelab $0 budget alert"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "1"
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = []
    disable_default_iam_recipients   = false
  }
}
