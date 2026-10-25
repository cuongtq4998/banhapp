# Deployment and Operations

| Field        | Value |
| ------------ | ----- |
| Version      | 1.0 |
| Last updated | 2026-10-25 |
| Status       | Draft |
| Owner        | atlas-architect (design), forge-dev (keeps it true) |
| Based on     | architecture.md v1.0; product/place-order.md v1.2 |
| Related      | ADR-0001 to ADR-0005; auth.md; data-model.md |

Provider names below are the recommendation in ADR-0003 (pending owner choice, costs money). The repository holds only variable names; no hostnames, accounts or keys.

## 1. Environments

| Environment | Purpose | Data | Who deploys |
| ----------- | ------- | ---- | ----------- |
| local | Development and tests | Local PostgreSQL (container) with `backend/db/seed/sample.sql`; fake data | Each developer |
| staging | Pre-release checks, store review builds, device tests of Zalo and phone | Separate database, sample seed, fake orders only | CI on merge to the main branch (automatic) |
| production | Customers | Real shop data (after launch data is supplied); sample rows must be replaced before launch | CI with manual approval by the operator |

Staging and production are separate hosts and separate databases. Staging is optional until launch week if cost matters (a second small instance is an extra cost; flagged in section 9).

## 2. Roles

| Role | Duty |
| ---- | ---- |
| Owner | Approves paid services; holds store accounts and the offline backup decryption key |
| Operator | The technical person who releases and responds to alerts (name and contact kept outside the repository) |

## 3. Configuration

Backend variables (names only; `.env.example` lists the same names with empty values):

| Name | Meaning | Required | Where set |
| ---- | ------- | -------- | --------- |
| `APP_ENV` | `local`, `staging` or `production` | Yes | Host |
| `PORT` | Listen port | Yes | Host |
| `DATABASE_URL` | Application database connection (limited role) | Yes | Host secret store |
| `DATABASE_MIGRATION_URL` | Migration role connection | For migrations | CI secret, operator machine |
| `DATABASE_POOL_MAX` | Maximum connections (default 5; free plans limit connections) | No | Host |
| `SHOP_ID` | UUID of the shop served (single shop at launch) | Yes | Host |
| `TRUST_PROXY` | Read the client IP from the proxy header | Yes in staging and production | Host |
| `ORDERING_ENABLED` | `true` or `false`; false returns 503 `ORDERING_PAUSED` | No (default true) | Host |
| `RATE_LIMIT_READ_PER_MINUTE` | Default 120 | No | Host |
| `RATE_LIMIT_ORDER_PER_HOUR` | Default 10 | No | Host |
| `ORDER_MAX_PER_PHONE_PER_DAY` | Default 5 | No | Host |
| `PUBLIC_ASSET_BASE_URL` | Prefix for `image_url` if assets move to another host | No | Host |
| `LOG_LEVEL` | `info` default | No | Host |

Mobile build settings (per build configuration, not secrets): `API_BASE_URL` (staging, production). Android `usesCleartextTraffic=false`; iOS keeps App Transport Security defaults.

CI and backup variables: see auth.md section 5.

## 4. Build & Release

Pipeline (GitHub Actions, free for public repositories; macOS runner minutes for public repositories are free, unverified):

1. Pull request: backend unit and integration tests against a PostgreSQL service container (including the parallel-order test of AC-22); Android build and unit tests; iOS build and unit tests (macOS runner); contract fixture checks; lint.
2. Merge to main: deploy the backend to staging; run database migrations first, then the new backend version (migrations are forward-compatible, data-model.md section 8).
3. Release tag `backend-vX.Y.Z`: operator approves, the same image deploys to production.
4. Mobile: tags `ios-vX.Y.Z` and `android-vX.Y.Z`; signed builds are produced locally or by CI with signing secrets (not in the repository); upload to TestFlight and Play internal testing.

Versioning: backend `MAJOR.MINOR.PATCH`; API version in the path (api.md section 6); mobile marketing version `MAJOR.MINOR.PATCH`, build number increases on each upload.

Changing shop data before the owner slice exists: the operator applies a reviewed SQL change (prices, limit, districts, slots, contacts) in a pull request that touches `backend/db/seed/` or a migration, then runs it with the migration role; setting `is_sample = false` marks real values (ADR-0013).

Store submission notes (unverified until the accounts exist):

| Item | Apple App Store | Google Play |
| ---- | --------------- | ----------- |
| Privacy policy URL | Required; use `https://<API_HOST>/privacy` | Required to complete the Data safety form (support.google.com answer 10787469) |
| Data declared | Contact information: name, phone number, physical address; used for app functionality; linked to the order; not used for tracking | Personal info: name, phone number, address; collected; not shared with third parties; encrypted in transit; no in-app account, so no account deletion flow; deletion on request to the shop |
| Sign-in | None (matches Apple guidance cited in PRD S-2) | None |
| Build requirement | Xcode 26 SDK or later for uploads from 2026-04-28 | Current target API level requirement (check at submission) |
| Review hints | State that payment is outside the app | Same |

The Data safety form must also cover data collected through third-party libraries; the apps use none that collect data (ADR-0007), so the answer stays "none beyond the order".

Launch checklist: real shop data loaded and no `is_sample = true` rows; privacy page text final including data location and retention (BR-12, owner); Zalo and phone tested on devices with and without Zalo; backup restore tested once; uptime monitor and alerts active; store listings approved.

## 5. Infrastructure

| Component | Choice (recommendation) | Reference |
| --------- | ----------------------- | --------- |
| API runtime | One always-on container instance (0.5 vCPU, 512 MB) in a Singapore region, deployed from the repository | ADR-0003 |
| Database | Managed PostgreSQL in the same region, free plan at launch | ADR-0002, ADR-0003 |
| TLS and domain | Provided by the host; one custom domain `<API_HOST>` (domain name costs money, about USD 10 to 15 per year, estimate) | Owner approval |
| Backups | Encrypted dumps to separate object storage (free tier) | Section 6 |
| CI | GitHub Actions | |

Single instance, no autoscaling: expected peak is about 5 requests per second (architecture.md section 8).

## 6. Backup & Restore

| Item | Value |
| ---- | ----- |
| Method | Nightly `pg_dump` by a scheduled workflow using a read-only database role; output encrypted with `age` using a public key; uploaded to private object storage |
| Frequency and retention | Every 24 hours; keep 14 daily and 8 weekly dumps; the provider's own point-in-time window is an extra, not relied on (length on free plans unverified) |
| Recovery point | 24 hours |
| Recovery time | 4 hours |
| Not allowed | Dumps as workflow artifacts of this public repository (artifacts of public repositories are readable by others, unverified) |
| Restore test | Required before launch and every 3 months: download one dump, decrypt with the offline private key, restore into a scratch database, run the reconciliation query (`day_load` equals the sum of cakes of non-cancelled orders), record the date in the operations log. A backup counts only after this test succeeds |

## 7. Observability

| What | How | Retention |
| ---- | --- | --------- |
| Logs | Structured JSON to stdout: time, level, request id, method, path, status, duration, platform, app version, error code. Never name, phone, address, note or body | 30 days at the host (estimate) |
| Health | `GET /healthz` checked every 5 minutes by an external uptime monitor and by the host | |
| Metrics | From logs: requests, 5xx rate, p95 duration, orders created, 409 and 429 counts | |

Alerts (every alert has an owner and an action):

| Alert | Threshold | Told | Action |
| ----- | --------- | ---- | ------ |
| Health check fails | 2 consecutive failures (10 minutes) | Operator by email | Check host and database status; restart; roll back if after a release |
| 5xx rate | More than 5% of requests over 15 minutes | Operator | Read logs by request id; roll back |
| `POST /v1/orders` p95 over 8 s | 3 consecutive 5-minute windows | Operator | Likely database cold start or limits: consider the paid always-on database plan (ADR-0003 option B) |
| Burst of 429 or orders | More than 50 `RATE_LIMITED` or 30 orders in 15 minutes | Operator, then owner | Check for abuse; set `ORDERING_ENABLED=false` if needed and tell the owner |
| Nightly backup failed | Workflow failure | Operator | Re-run; fix credentials; do not skip two nights |
| Database nearing free limit | Storage above 80% of the plan | Operator | Plan upgrade (owner approval) |

Cold start of an idle free database: the first request after idle may take extra seconds (unverified); the 10-second client timeout with the idempotent retry covers it. The uptime check every 5 minutes also keeps the database warm during business hours (this keeps compute active and may use free compute hours; check the plan limits).

## 8. Rollback

Backend:

1. Open the host's deploy history and redeploy the previous successful image (about 5 minutes).
2. If a migration ran, check whether it was an additive change: the previous version still works with it (data-model.md section 8). If a migration was destructive (should not be), restore from the last dump (section 6) and tell the owner about the lost orders window.
3. Verify `/healthz`, `GET /v1/catalog` and one test order on staging.
4. Record the incident in the operations log.

Mobile: halt the staged rollout in the store consoles and publish a fixed build; old app versions stay compatible because API `v1` is additive only (api.md section 6). A server change that breaks an app version is a defect.

Emergency stop of ordering: set `ORDERING_ENABLED=false` and restart; customers see `ERR_SERVER` and can contact the shop by Zalo or phone.

## 9. Cost Notes

All figures are estimates from public pages read on 2026-10-25; confirm before purchase. Every paid item needs owner approval.

| Item | Estimate | Source |
| ---- | -------- | ------ |
| API instance (always-on, small) | About USD 7 per month | https://render.com/articles/how-much-does-cloud-application-hosting-cost-for-small-businesses (medium) |
| Managed PostgreSQL free plan | USD 0 (0.5 GB, idle suspend) | https://neon.com/pricing (medium) |
| Always-on database if cold starts hurt | About USD 15 to 20 per month more (0.25 CU for 730 hours at about USD 0.106 per CU-hour, plus storage) | https://neon.com/pricing (medium, calculation) |
| Backup object storage | USD 0 within a 10 GB free tier | Third-party summaries of Cloudflare R2 pricing (low to medium) |
| Domain name | About USD 10 to 15 per year | Not researched (unverified) |
| Apple Developer Program | USD 99 per year | Apple pricing, not fetched (unverified) |
| Google Play developer registration | USD 25 one time | Google pricing, not fetched (unverified) |
| GitHub Actions | USD 0 for a public repository | Not fetched (unverified) |
| Staging instance (optional) | About USD 7 per month more | Same as API instance |

Estimated running cost: about USD 7 per month (production only) plus about USD 99 per year and USD 25 once for the stores and a domain. Order volume has almost no effect at this size.

## 10. Open Questions / Change log

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| DP-Q1 | Owner approval of costs in section 9 and hosting choice (ADR-0003) | Money, customer data | Yes for provisioning | business | Open (owner) | |
| DP-Q2 | Operator name and alert email | Alerts need an owner | Yes for launch | business | Open (owner) | |
| DP-Q3 | Is a staging environment wanted before launch (extra cost) | Cost against safety | No | business | Open (owner) | |

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version. |
