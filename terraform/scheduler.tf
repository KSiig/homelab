# Cloud Scheduler for priskurven-collect.
#
# One job per M1 spec — GCP free tier allows 3 jobs per billing account,
# tilbudstracker uses two, priskurven gets the third.
#
# Cron is locked at 06:00 Europe/Copenhagen, same as tilbudstracker-daily
# (SII-91 Q1 — locked 2026-09-18 by inline comment, applied 2026-09-19).
resource "google_cloud_scheduler_job" "priskurven_daily" {
  name             = "priskurven-daily"
  description      = "Triggers priskurven-collect daily at 06:00 Europe/Copenhagen (M1 — Shelf collector)."
  schedule         = "0 6 * * *"
  time_zone        = "Europe/Copenhagen"
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.priskurven_collect.url

    oidc_token {
      service_account_email = google_service_account.priskurven_fn.email
      audience              = google_cloudfunctions2_function.priskurven_collect.url
    }
  }
}
