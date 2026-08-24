provider "cloudflare" {}

resource "cloudflare_d1_database" "homelab" {
  account_id       = var.cloudflare_account_id
  name             = "homelab"
  read_replication = { mode = "disabled" }
}
