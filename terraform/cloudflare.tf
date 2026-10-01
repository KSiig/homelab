provider "cloudflare" {}

# Look up the siig.tech zone id from the zone name. Cloudflare zone
# names are globally unique, so the data source only needs `name` (no
# `account_id`; v5 provider removed that argument).
data "cloudflare_zone" "siig_tech" {
  name = "siig.tech"
}

# Register priskurven.siig.tech as a custom domain on the
# `priskurven` Worker (created by `npx wrangler deploy` in
# KSiig/priskurven, not by this Terraform). The Workers Custom
# Domains API creates the CNAME record in the zone and provisions
# SSL on apply — Terraform owns the hostname registration.
#
# Once this is in place, wrangler.toml in priskurven can drop its
# `[[routes]] custom_domain = true` line so the deploy doesn't try
# to register the same hostname twice. The wrangler deploy in SII-114
# is left untouched in this PR so the two changes are independently
# mergeable.
#
# Required Cloudflare API token permissions:
#   * Account → Workers Scripts:Edit  (register hostname with Worker)
#   * Zone    → Zone:Read            (resolve zone id from name)

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

resource "cloudflare_workers_custom_domain" "priskurven_history" {
  account_id = var.cloudflare_account_id
  zone_id    = data.cloudflare_zone.siig_tech.id
  hostname   = "priskurven.siig.tech"
  service    = "priskurven"
}
