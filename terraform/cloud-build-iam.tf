# Cloud Build needs these roles when invoked as the runtime SA
# (priskurven-fn@<project>.iam.gserviceaccount.com) for Cloud Functions Gen 2.
# Without `build_config.service_account` set explicitly, Cloud Build
# defaults to the project's Compute Engine SA and Terraform fails the
# function create with `iam.serviceAccountUser` 403. Routing Cloud Build
# at the runtime SA keeps the default Compute SA out of the trust path
# and matches the per-runtime-SA stance in wif.tf.

locals {
  priskurven_fn_build_roles = toset([
    "roles/cloudbuild.builds.editor",
    "roles/logging.logWriter",
    "roles/artifactregistry.writer",
  ])
}

resource "google_project_iam_member" "priskurven_fn_build" {
  for_each = local.priskurven_fn_build_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.priskurven_fn.email}"
}

# Cloud Build also needs to read the source object (function.zip) from the
# priskurven bucket. Scoped to the bucket rather than project-wide.
resource "google_storage_bucket_iam_member" "priskurven_fn_build_reader" {
  bucket = google_storage_bucket.priskurven.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.priskurven_fn.email}"
}

# Gen 2 copies the zip into Google-managed staging buckets named
# gcf-v2-sources-*, gcf-v2-uploads-*, and run-sources-* before Cloud
# Build fetches it. objectViewer on the user bucket above is not
# enough; the fetch step reads the staging bucket. Grant at project
# level (matches Google's custom-build-SA docs) with an IAM condition
# so the runtime SA cannot read unrelated buckets (e.g. tfstate).
# Do not bind IAM on the staging bucket itself: GCP creates it lazily,
# and google_storage_bucket_iam_member 404s if the bucket is missing.
resource "google_project_iam_member" "priskurven_fn_gcf_sources" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.priskurven_fn.email}"

  condition {
    title       = "gcf-managed-source-buckets"
    description = "Cloud Build fetch of Gen 2 staged source"
    expression  = <<-EOT
      resource.type == "storage.googleapis.com/Object" && (
        resource.name.startsWith("projects/_/buckets/gcf-v2-sources-") ||
        resource.name.startsWith("projects/_/buckets/gcf-v2-uploads-") ||
        resource.name.startsWith("projects/_/buckets/run-sources-")
      )
    EOT
  }
}
