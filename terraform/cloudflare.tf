provider "cloudflare" {}

resource "cloudflare_d1_database" "homelab" {
  account_id       = var.cloudflare_account_id
  name             = "homelab"
  read_replication = { mode = "disabled" }
}

# Priskurven D1 database (M1 — Shelf collector).
# Read by SII-99 (history Worker) and SII-109 (homelab CI that applies
# D1 migrations remotely) via terraform output `priskurven_d1_database_id`.
# Created here (not in SII-109) because Terraform manages state and CI
# consumes the output before the migrations job runs.
resource "cloudflare_d1_database" "priskurven" {
  account_id       = var.cloudflare_account_id
  name             = "priskurven"
  read_replication = { mode = "disabled" }
}

output "priskurven_d1_database_id" {
  description = "D1 database id for priskurven. Consumed by SII-99 (history Worker wrangler.toml) and SII-109 (homelab D1 migration CI) after apply."
  value       = cloudflare_d1_database.priskurven.id
}
