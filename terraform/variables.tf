variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "function_runtime_service_accounts" {
  description = "Emails of Cloud Functions runtime service accounts that the GitHub Actions deployer may impersonate via roles/iam.serviceAccountUser. Empty by default; populated when Cloud Functions are added in a later PR. Kept as a list so SA User can be granted per-runtime-SA instead of project-wide."
  type        = list(string)
  default     = []
}

