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

