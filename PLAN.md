# Homelab: Hybrid Cloud Setup

Personal infrastructure running on GCP + Cloudflare free tiers.

- **GCP Cloud Functions** — scheduled jobs (scrapers, agentic AI loops)
- **Cloudflare Pages + Workers** — web apps and APIs
- **Cloudflare D1** — SQLite databases (accessible from both platforms)

## Architecture

```
                  ┌─────────────────────────────────┐
                  │         Cloudflare Edge          │
                  │                                  │
                  │  Pages ──── Workers ──── D1      │
                  │  (web UI)   (API)     (SQLite)   │
                  └──────────────────────────────────┘
                                  ▲
                                  │ D1 REST API
                                  │
                  ┌──────────────────────────────────┐
                  │              GCP                  │
                  │                                   │
                  │  Cloud Scheduler ── Cloud Functions│
                  │  (cron triggers)   (job runtime)  │
                  └──────────────────────────────────┘
                                  │
                                  ▼
                        External APIs
                  (Anthropic, grocery APIs, etc.)
```

### Why this split

| Concern | Platform | Reason |
|---------|----------|--------|
| Cron jobs | GCP Cloud Functions | 60 min max execution, 400K GB-s/month free — handles both quick scrapers and long-running agentic AI loops |
| Web apps | Cloudflare Pages | Unlimited requests + bandwidth on free tier, global edge, zero cold starts |
| Databases | Cloudflare D1 | SQLite-compatible, native from Workers, accessible from GCP via REST API. 5 GB storage, 5M reads/day, 100K writes/day free |
| Secrets | GCP Secret Manager | 6 active secret versions free. Cloudflare Workers get secrets via `wrangler secret put` |

### Free tier budget

| Service | Free allowance | Estimated usage |
|---------|---------------|-----------------|
| GCP Cloud Functions | 2M invocations, 400K GB-s/month | Tilbudstracker: ~30 invocations/month. Agentic jobs: ~100–500/month |
| GCP Cloud Scheduler | 3 jobs/account | 1 for tilbudstracker, 2 for future agents |
| Cloudflare Pages | Unlimited requests, 500 builds/month | 1–3 web apps |
| Cloudflare Workers | 100K requests/day | API backends for web apps |
| Cloudflare D1 | 5 GB, 5M reads/day, 100K writes/day | Tilbudstracker DB + future project DBs |

## Infrastructure as Code

```
homelab/
  terraform/
    main.tf                  # GCP provider, project config
    cloud-functions.tf       # function deployments
    scheduler.tf             # cron triggers
    secrets.tf               # secret manager entries
    variables.tf
    terraform.tfvars
  cloudflare/
    wrangler.toml            # workers + pages config
    d1-migrations/           # D1 schema migrations
  projects/
    tilbudstracker/          # see below
    agent-template/          # template for new agentic cron projects
```

### GCP setup

Terraform manages all GCP resources. One project, billing account with $0 budget alert.

```hcl
# terraform/main.tf
provider "google" {
  project = "homelab-<id>"
  region  = "europe-west1"  # Belgium — closest free-tier region to Denmark
}
```

Key resources:
- `google_cloudfunctions2_function` — one per cron job
- `google_cloud_scheduler_job` — cron triggers (HTTP to function URL)
- `google_secret_manager_secret` — API keys, tokens

### Cloudflare setup

Wrangler CLI manages Workers, Pages, and D1. One account, one zone (if custom domain wanted, otherwise *.pages.dev).

```toml
# cloudflare/wrangler.toml
name = "homelab"
compatibility_date = "2026-08-01"

[[d1_databases]]
binding = "DB"
database_name = "homelab"
database_id = "<created-on-first-deploy>"
```

## Project: tilbudstracker

Grocery offer tracker — scrapes Danish offers from etilbudsavis.dk via the Tjek API, stores in SQLite, web UI for browsing results.

Source: https://github.com/KSiig/tilbudstracker

### Current state

- TypeScript/Node.js scraper that writes to SQLite (`data/tilbud.db`)
- Tables: `stores`, `catalogs`, `offers`
- Skips previously-scraped catalogs (idempotent)
- Web UI: not yet built
- Docker image exists but was targeting K8s CronJob

### Deployment plan

**Scraper cron → GCP Cloud Function**

1. Refactor the scraper entry point to export a Cloud Functions handler:
   ```typescript
   import { HttpFunction } from "@google-cloud/functions-framework";
   export const scrape: HttpFunction = async (req, res) => {
     // existing scrape logic, but write to D1 instead of local SQLite
     res.status(200).send("done");
   };
   ```
2. Replace direct SQLite writes with D1 REST API calls (Cloudflare provides an HTTP API for D1 — the function POSTs SQL statements and gets results back)
3. Deploy via Terraform as a Gen 2 Cloud Function (Node.js 22 runtime, 256 MB memory, 5 min timeout)
4. Cloud Scheduler triggers it daily (or twice daily) via HTTP

**Database → Cloudflare D1**

1. Migrate the existing SQLite schema to D1:
   ```sql
   -- d1-migrations/0001_initial.sql
   CREATE TABLE stores (
     id TEXT PRIMARY KEY,
     name TEXT NOT NULL,
     -- existing columns from tilbudstracker
   );
   CREATE TABLE catalogs (...);
   CREATE TABLE offers (...);
   ```
2. D1 is SQLite under the hood — the existing schema translates directly
3. Both the GCP function (via REST API) and the Cloudflare Worker (via native binding) access the same database

**Web UI → Cloudflare Pages + Workers**

1. Build a simple web app (likely SvelteKit, Astro, or plain HTML + Workers API):
   - Browse current offers by store/category
   - Search by product name
   - Price trend charts per product
2. Workers backend queries D1 directly via native binding (no REST API overhead)
3. Deploy via `wrangler pages deploy`

### Data flow

```
Cloud Scheduler (daily 06:00 UTC)
  │
  ▼
Cloud Function (scrape)
  │  fetch offers from Tjek API
  │  write to D1 via REST API
  ▼
Cloudflare D1 (homelab database)
  ▲
  │  native D1 binding
  │
Cloudflare Worker (API)
  ▲
  │
Cloudflare Pages (web UI)
```

### Migration steps

1. Set up GCP project + Cloudflare account (if not already)
2. Create D1 database, run initial migration
3. Seed D1 with existing data from `data/tilbud.db` (one-time import via `wrangler d1 execute`)
4. Refactor scraper to use D1 REST API instead of local SQLite
5. Deploy scraper as Cloud Function + Scheduler trigger
6. Build and deploy web UI on Pages
7. Verify cron runs, data flows through, UI renders

## Project template: agentic cronjobs

For future AI agent jobs (the Sympozium-style workloads).

### Pattern

```typescript
import { HttpFunction } from "@google-cloud/functions-framework";
import Anthropic from "@anthropic-ai/sdk";

export const agentJob: HttpFunction = async (req, res) => {
  const client = new Anthropic(); // key from env/Secret Manager

  // agentic loop — sequential tool calls, decision logic, etc.
  // can run for up to 60 minutes on Gen 2 Cloud Functions
  // write results to D1, send notifications, etc.

  res.status(200).send({ result });
};
```

### Terraform template

```hcl
resource "google_cloudfunctions2_function" "agent_job" {
  name     = "agent-<name>"
  location = "europe-west1"

  build_config {
    runtime     = "nodejs22"
    entry_point = "agentJob"
    source { /* Cloud Source or GCS bucket */ }
  }

  service_config {
    max_instance_count = 1
    timeout_seconds    = 3600  # 60 min max
    available_memory   = "256Mi"
    environment_variables = {
      D1_ACCOUNT_ID  = var.cloudflare_account_id
      D1_DATABASE_ID = var.d1_database_id
    }
    secret_environment_variables {
      key        = "ANTHROPIC_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.anthropic_key.secret_id
      version    = "latest"
    }
  }
}

resource "google_cloud_scheduler_job" "agent_trigger" {
  name     = "agent-<name>-trigger"
  schedule = "0 */6 * * *"  # every 6 hours
  time_zone = "Europe/Copenhagen"

  http_target {
    uri         = google_cloudfunctions2_function.agent_job.url
    http_method = "POST"
    oidc_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}
```

### Budget math

At 256 MB memory, a 5-minute agentic run uses ~75 GB-seconds. The free tier (400K GB-s) allows ~5,300 such runs/month. Even with longer 15-minute runs (~225 GB-s each), that's ~1,700 runs/month — more than enough for personal use.

## CI/CD

Two reusable GitHub Actions workflows live at `.github/workflows/`:

- **`terraform.yml`** — Terraform plan on PR, apply on merge to `main`. Uses GCP Workload Identity Federation (no service account keys).
- **`cloudflare-deploy.yml`** — reusable workflow that deploys Cloudflare Workers and Pages via `wrangler` CLI. Authenticates with the `CLOUDFLARE_API_TOKEN` secret and the `CLOUDFLARE_ACCOUNT_ID` repository variable. Triggers on push to `main` when `cloudflare/**` changes, on `workflow_dispatch`, and via `workflow_call` from other repos.

### Calling the Cloudflare workflow from a consumer repo

```yaml
# From KSiig/tilbudstracker — .github/workflows/cloudflare-web.yml
name: Deploy Cloudflare Pages
on:
  push:
    branches: [main]
    paths: ["web/**"]
jobs:
  deploy:
    uses: KSiig/homelab/.github/workflows/cloudflare-deploy.yml@main
    with:
      working_directory: web
      command: pages deploy ./dist
      cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
    secrets:
      cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

Inputs the caller can override: `working_directory` (default `cloudflare`), `command` (default `deploy`), `node_version` (default `22`), `cloudflare_account_id` (falls back to `CLOUDFLARE_ACCOUNT_ID` env or `wrangler.toml`).

Secrets the caller must pass: `cloudflare_api_token` — map your repo's Cloudflare token into the slot. The homelab repo's `CLOUDFLARE_API_TOKEN` secret has `Account.Workers Scripts:Edit`, `Account.Pages:Edit`, and `Account.D1:Edit` scopes from SII-7. Consumer repos must use a token with equivalent scopes.

## Setup checklist

- [ ] Create GCP project with billing account + $0 budget alert
- [ ] Enable Cloud Functions, Cloud Scheduler, Secret Manager APIs
- [ ] Create Cloudflare account
- [ ] Create D1 database (`wrangler d1 create homelab`)
- [ ] Set up Terraform backend (GCS bucket or Terraform Cloud free tier)
- [ ] Set up GitHub Actions for both platforms
- [ ] Migrate tilbudstracker scraper to Cloud Functions + D1
- [ ] Build tilbudstracker web UI on Cloudflare Pages
- [ ] Deploy first agentic cronjob
