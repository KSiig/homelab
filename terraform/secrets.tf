# Secret Manager entries for priskurven.
#
# Two categories here:
#   1. cloudflare-api-token — references the pre-existing secret created
#      outside this Terraform module (referenced by PLAN.md, used by
#      tilbudstracker). Looked up as a data source; do not create it
#      twice.
#   2. Salling Algolia secrets — placeholder resources only. Versions
#      are intentionally not bound on the function (SII-91 fail clause).
#      SII-102 (human) adds the actual versions after SII-97 lands.

# Lookup the existing Cloudflare API token secret. Created manually
# in Secret Manager before Terraform-managed projects existed.
data "google_secret_manager_secret" "cloudflare_api_token" {
  project   = var.project_id
  secret_id = "cloudflare-api-token"
}

# Salling Algolia search-only secrets (Netto, Føtex, BilkaToGo).
# SII-97 reads the env names below at function runtime; SII-102
# populates the values via Secret Manager as versions of these
# resources. Terraform creates only the metadata here.
resource "google_secret_manager_secret" "netto_path" {
  project   = var.project_id
  secret_id = "NETTO_PATH"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "netto_app_id" {
  project   = var.project_id
  secret_id = "NETTO_APP_ID"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "netto_key" {
  project   = var.project_id
  secret_id = "NETTO_KEY"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "fotex_path" {
  project   = var.project_id
  secret_id = "FOTEX_PATH"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "fotex_app_id" {
  project   = var.project_id
  secret_id = "FOTEX_APP_ID"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "fotex_key" {
  project   = var.project_id
  secret_id = "FOTEX_KEY"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "bilkatogo_path" {
  project   = var.project_id
  secret_id = "BILKATOGO_PATH"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "bilkatogo_app_id" {
  project   = var.project_id
  secret_id = "BILKATOGO_APP_ID"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "bilkatogo_key" {
  project   = var.project_id
  secret_id = "BILKATOGO_KEY"

  replication {
    auto {}
  }
}

# Bind the runtime SA as a Secret Accessor on the Salling secrets so
# the function can read them at runtime once SII-102 has populated
# versions. Same role for cloudflare-api-token so the function can
# read the D1 token.
# Bind the runtime SA as a Secret Accessor on every secret this function
# needs to read at runtime.
#
# For the Salling Algolia secrets (Terraform-managed below), we use the
# `secret_id` (short name) of each resource. For the pre-existing
# cloudflare-api-token (data source), we use the short name explicitly —
# the data source's `name` attribute is the full path, not what
# google_secret_manager_secret_iam_member.secret_id expects.
locals {
  priskurven_fn_secret_ids = toset(concat(
    [
      "cloudflare-api-token",
    ],
    [
      google_secret_manager_secret.netto_path.secret_id,
      google_secret_manager_secret.netto_app_id.secret_id,
      google_secret_manager_secret.netto_key.secret_id,
      google_secret_manager_secret.fotex_path.secret_id,
      google_secret_manager_secret.fotex_app_id.secret_id,
      google_secret_manager_secret.fotex_key.secret_id,
      google_secret_manager_secret.bilkatogo_path.secret_id,
      google_secret_manager_secret.bilkatogo_app_id.secret_id,
      google_secret_manager_secret.bilkatogo_key.secret_id,
    ],
  ))
}

resource "google_secret_manager_secret_iam_member" "priskurven_fn_secrets" {
  for_each = local.priskurven_fn_secret_ids

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.priskurven_fn.email}"

  depends_on = [
    google_secret_manager_secret.netto_path,
    google_secret_manager_secret.netto_app_id,
    google_secret_manager_secret.netto_key,
    google_secret_manager_secret.fotex_path,
    google_secret_manager_secret.fotex_app_id,
    google_secret_manager_secret.fotex_key,
    google_secret_manager_secret.bilkatogo_path,
    google_secret_manager_secret.bilkatogo_app_id,
    google_secret_manager_secret.bilkatogo_key,
  ]
}
