provider "cloudflare" {}

# Look up the siig.tech zone id from the zone name. In provider v5,
# the data source uses a `filter` nested attribute instead of `name`
# directly (the v4 `name` argument became read-only).
data "cloudflare_zone" "siig_tech" {
  filter = {
    name = "siig.tech"
  }
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

# Register linear.siig.tech as a custom domain on the
# `linear-planner` Cloudflare Pages project. The project
# itself is created by `wrangler pages deploy` from the
# KSiig/linear-planner deploy workflow (SII-119), not by
# this Terraform — `terraform apply` will fail with
# "project not found" until SII-119 has merged and run.
#
# NOTE: `cloudflare_pages_domain` (v5) binds the hostname to
# the Pages project but does NOT create a DNS record in the
# zone. Compare with `cloudflare_workers_custom_domain`
# above, which DOES create the CNAME. SII-120 missed the
# companion CNAME; this PR (SII-120a) adds it.
resource "cloudflare_pages_domain" "linear_planner" {
  account_id   = var.cloudflare_account_id
  project_name = "linear-planner"
  name         = "linear.siig.tech"
}

# DNS record for the custom domain above. CNAME
# `linear.siig.tech` -> `linear-planner.pages.dev`, proxied
# so Cloudflare's edge terminates SSL and routes the request
# to the Pages project that the resource above just registered.
resource "cloudflare_dns_record" "linear_siig_tech" {
  zone_id = data.cloudflare_zone.siig_tech.id
  name    = "linear.siig.tech"
  type    = "CNAME"
  content = "linear-planner.pages.dev"
  proxied = true
  ttl     = 1
  comment = "SII-120a: companion CNAME for cloudflare_pages_domain.linear_planner. SII-120 missed this record; Pages registers the hostname but does not create the CNAME itself (unlike cloudflare_workers_custom_domain)."
}

# Note: re-apply of SII-120a's CNAME after Cloudflare token scope was extended
# with Zone/DNS/Edit. The original PR (#32) merged but token lacked DNS:Edit, so
# the apply returned 403. Token scope fixed, this push re-runs the workflow.
