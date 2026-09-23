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