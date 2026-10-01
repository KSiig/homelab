# Cloud Functions (Gen 2) for priskurven.
#
# Owned by SII-91 (homelab Terraform). Created here, on terraform/**,
# so the agentic deploy path is GitHub Actions WIF → terraform apply →
# function URL exists, not laptop `gcloud functions deploy`.
#
# Pinned names (from SII-91 issue body):
#   Function name:   priskurven-collect
#   Entry point:     handler   (KSiig/priskurven src/index.ts; SII-103)
#   Runtime SA:      priskurven-fn@lateral-booking-506410-k4.iam.gserviceaccount.com
#   GCS bucket:      lateral-booking-506410-k4-priskurven
#   GCS object:      function.zip
#   Region:          europe-west1
#   Runtime:         nodejs22
#   Memory:          256Mi
#   Timeout:         300s

# Bucket that holds the function source. SII-101 (CI: deploy via WIF on
# main) uploads the real zip to the same object after merge.
resource "google_storage_bucket" "priskurven" {
  name     = "lateral-booking-506410-k4-priskurven"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = false
}

# Cloud Functions Gen 2 uses the project-level Cloud Functions service
# agent (`service-<PROJECT_NUMBER>@gcf-admin-robot.iam.gserviceaccount.com`)
# to verify the source object exists and is readable before Cloud Build
# runs. Without this grant, `gcloud functions deploy --source=gs://...`
# 401s with "Anonymous caller does not have storage.objects.get access"
# even when the deployer SA has full storage admin on the bucket.
#
# The runtime SA already has objectViewer (see cloud-build-iam.tf), but
# Cloud Functions does the source-read preflight under the CF service
# agent, not the runtime SA. Granting objectViewer to the CF-SA fixes
# it; the CF-SA's own role (`roles/cloudfunctions.serviceAgent`) is
# provisioned automatically when the Cloud Functions API is enabled,
# and is not enough on its own to read arbitrary GCS buckets.
#
# Reuses data.google_project.current already defined in budget.tf;
# Terraform disallows duplicate data sources with the same kind+name.
resource "google_storage_bucket_iam_member" "priskurven_gcf_source_reader" {
  bucket = google_storage_bucket.priskurven.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${data.google_project.current.number}@gcf-admin-robot.iam.gserviceaccount.com"
}

# Placeholder zip so `google_cloudfunctions2_function.storage_source`
# resolves a real object at apply time. SII-101 overwrites this object
# on every green main. The placeholder must never be the deployed handler.
#
# SII-112: ignore byte-level changes so a later `terraform apply` does
# not replace the CI-uploaded object with this placeholder. The
# function's lifecycle block (below) already ignores bucket/object
# names; this resource has no such block, so the next plan would
# otherwise rewrite `function.zip` from `terraform/placeholder/`.
resource "google_storage_bucket_object" "priskurven_function_zip" {
  name   = "function.zip"
  bucket = google_storage_bucket.priskurven.name
  source = "${path.module}/placeholder/function.zip"

  lifecycle {
    ignore_changes = [
      source,
      content,
      detect_md5hash,
    ]
  }
}

# Runtime service account for the function. Empty list passed into
# var.function_runtime_service_accounts at the top of wif.tf would not
# grant SA User; we add the SA to that list below so the GitHub Actions
# deployer can impersonate it (scoped, not project-wide).
resource "google_service_account" "priskurven_fn" {
  account_id   = "priskurven-fn"
  display_name = "priskurven-collect runtime SA"
  description  = "Runtime identity for the priskurven-collect Cloud Function (M1 — Shelf collector)."
}

# Register the runtime SA with WIF so the GitHub Actions deployer can
# impersonate it via roles/iam.serviceAccountUser. Scoped to this one SA
# (project-wide SA User is intentionally avoided — see wif.tf).
resource "google_service_account_iam_member" "priskurven_fn_user" {
  service_account_id = google_service_account.priskurven_fn.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_actions.email}"

  depends_on = [google_service_account.priskurven_fn]
}

# Gen 2 Cloud Function. Reads `handler` from GCS object above.
# Env vars match SII-91/SII-93 contract: same names as the tilbudstracker
# function, against the new priskurven database.
resource "google_cloudfunctions2_function" "priskurven_collect" {
  name        = "priskurven-collect"
  location    = var.region
  description = "Daily shelf-price collector for priskurven (M1 — Shelf collector)."

  build_config {
    runtime         = "nodejs22"
    entry_point     = "handler"
    service_account = google_service_account.priskurven_fn.id

    source {
      storage_source {
        bucket = google_storage_bucket.priskurven.name
        object = google_storage_bucket_object.priskurven_function_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256Mi"
    timeout_seconds       = 300
    service_account_email = google_service_account.priskurven_fn.email

    environment_variables = {
      DB_MODE                   = "d1"
      CLOUDFLARE_ACCOUNT_ID     = var.cloudflare_account_id
      CLOUDFLARE_D1_DATABASE_ID = cloudflare_d1_database.priskurven.id
    }

    # D1 REST auth — reuse the existing Cloudflare token. Do NOT bind
    # Salling secret versions: the function must start when those keys
    # are absent (SII-100 proves Rema + Min Købmand without Salling).
    secret_environment_variables {
      key        = "CLOUDFLARE_API_TOKEN"
      project_id = var.project_id
      # cloudfunctions2.secret_environment_variables.secret expects the
      # short secret name, not the full resource path. The data source
      # exports `name` (full path); we pin the short id explicitly to
      # match the convention used by the Salling secrets below.
      secret  = "cloudflare-api-token"
      version = "latest"
    }
  }

  depends_on = [
    google_storage_bucket_object.priskurven_function_zip,
    google_service_account_iam_member.priskurven_fn_user,
    google_secret_manager_secret_iam_member.priskurven_fn_secrets,
    google_project_iam_member.priskurven_fn_build,
    google_storage_bucket_iam_member.priskurven_fn_build_reader,
    google_project_iam_member.priskurven_fn_gcf_sources,
    google_storage_bucket_iam_member.priskurven_fn_gcf_sources_reader,
  ]

  # The function zip is replaced by `KSiig/priskurven/.github/workflows/ci.yml`
  # (SII-101) on every push to main. Terraform manages the bucket and the
  # placeholder on first apply; subsequent applies leave the storage_source
  # alone so CI uploads survive.
  lifecycle {
    ignore_changes = [
      build_config[0].source[0].storage_source[0].bucket,
      build_config[0].source[0].storage_source[0].object,
    ]
  }
}

# Cloud Scheduler job `priskurven-daily` invokes this function with an
# OIDC token impersonating the runtime SA (`priskurven-fn`). Cloud Run
# then checks whether that principal has `roles/run.invoker` on the
# service. With `--no-allow-unauthenticated` (SII-113 contract) the
# function ships with no invokers at all, and SII-91's Terraform did
# not grant the runtime SA invoker — so the Scheduler's first attempt
# (12:36 UTC on 2026-10-01) returned 403:
#
#   The request was not authenticated. Either allow unauthenticated
#   invocations or set the proper Authorization header. The IAM
#   principal lacks {run.routes.invoke} permission.
#
# Grant invoker to the runtime SA so the OIDC token is accepted.
# Without this binding, every scheduled run 403s with the message above.
resource "google_cloud_run_service_iam_member" "priskurven_collect_invoker" {
  location = google_cloudfunctions2_function.priskurven_collect.location
  project  = google_cloudfunctions2_function.priskurven_collect.project
  service  = google_cloudfunctions2_function.priskurven_collect.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.priskurven_fn.email}"
}
