# Deployment and Operations

| Field        | Value |
| ------------ | ----- |
| Version      | 1.2 |
| Last updated | 2026-10-26 |
| Status       | Draft |
| Owner        | atlas-architect (design), forge-dev (keeps it true) |
| Based on     | architecture.md v1.0; product/place-order.md v1.2 |
| Related      | ADR-0001 to ADR-0005; auth.md; data-model.md |

Provider names below are the free trial setup of ADR-0003 (Accepted for the trial; no spend). [v1.1 | 2026-10-25] The repository holds only variable names; no hostnames, accounts or keys.

## 1. Environments

| Environment | Purpose | Data | Who deploys |
| ----------- | ------- | ---- | ----------- |
| local | Development and tests | Local PostgreSQL (container, `docker compose` in `backend/`) with `backend/db/seed/sample.sql`; fake data; run with `swift run` natively on macOS [v1.1 | 2026-10-25] | Each developer |
| staging | Pre-release checks, store review builds, device tests of Zalo and phone | Separate database, sample seed, fake orders only | CI on merge to the main branch (automatic) |
| production | Customers | Real shop data (after launch data is supplied); sample rows must be replaced before launch | CI with manual approval by the operator |

Staging and production are separate services and separate databases. On the free plans a staging service and a second Neon project cost nothing (Neon allows 100 projects; Render's 750 hours are shared per workspace, and a sleeping service uses none). [v1.1 | 2026-10-25]

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
| `PORT` | Listen port (Vapor binds `0.0.0.0` on it) | Yes | Host |
| `DATABASE_URL` | Application database connection (limited role) | Yes in staging and production; optional when `APP_ENV=local` (the server then starts with the shallow health check only and logs a warning) [v1.2 | 2026-10-26] | Host secret store |
| `DATABASE_MIGRATION_URL` | Migration role connection | For migrations | CI secret, operator machine |
| `DATABASE_POOL_MAX` | Maximum connections per instance (default 5; free plans limit connections); direct, not pooled, connection string (ADR-0002) | No | Host |
| `SHOP_ID` | UUID of the shop served (single shop at launch) | Yes from slice 1 (not read by slice 0) [v1.2 | 2026-10-26] | Host |
| `TRUST_PROXY` | Read the client IP from the proxy header | Yes in staging and production from slice 3 (rate limits); not read by slice 0 [v1.2 | 2026-10-26] | Host |
| `ORDERING_ENABLED` | `true` or `false`; false returns 503 `ORDERING_PAUSED` | No (default true) | Host |
| `RATE_LIMIT_READ_PER_MINUTE` | Default 120 | No | Host |
| `RATE_LIMIT_ORDER_PER_HOUR` | Default 10 | No | Host |
| `ORDER_MAX_PER_PHONE_PER_DAY` | Default 5 | No | Host |
| `PUBLIC_ASSET_BASE_URL` | Prefix for `image_url` if assets move to another host | No | Host |
| `LOG_LEVEL` | `info` default | No | Host |

Mobile build settings (per build configuration, not secrets): `API_BASE_URL` (staging, production). Android `usesCleartextTraffic=false`; iOS keeps App Transport Security defaults.

CI variables (names only) [v1.2 | 2026-10-26]: secrets `STAGING_DATABASE_MIGRATION_URL`, `STAGING_RENDER_DEPLOY_HOOK_URL`; variable `STAGING_BASE_URL`; the deploy job reads them from a GitHub environment named `staging` and skips itself with a notice while the secrets are unset. The test job uses throwaway credentials of a service container that exist only in the workflow. Backup variables: see auth.md section 5.

Startup warning for sample rows (ADR-0013): the check that logs a warning when `APP_ENV=production` and any row has `is_sample = true` is not in slice 0; it is built in slice 4 (launch readiness). Until then the launch checklist item below is the only guard [v1.2 | 2026-10-26].

## 4. Build & Release

Pipeline (GitHub Actions, free for public repositories; macOS runner minutes for public repositories are free, unverified). The Swift backend is built only in CI, never on the host: a release build is slow and memory-heavy (ADR-0001). [v1.1 | 2026-10-25]

CI files [v1.2 | 2026-10-26]: `.github/workflows/backend.yml` (job `test` on `ubuntu-latest` in a `swift:6.2-noble` container with a `postgres:16` service: build, tests, `migrate --yes`, sample seed applied twice; job `image`: image build on pull requests, push to GHCR on main; job `deploy-staging`), `.github/workflows/ios.yml` and `.github/workflows/android.yml`; each is path-filtered to its component. `ubuntu-latest` is Ubuntu 24.04. The workflows do not yet include SwiftLint, a nightly backup or a production job; those arrive with their slices.

iOS runner [v1.2 | 2026-10-26]: `ios.yml` runs on `macos-latest` (macOS 26) and selects the newest installed Xcode, but the project file needs Xcode 27 and GitHub now offers an Xcode 27 image under the label `xcode-27` (generally available since 2026-10-15). Use `runs-on: xcode-27` (dev query).

1. Pull request: backend `swift build` and `swift test` on Linux (XCTVapor) against a PostgreSQL service container (including the parallel-order test of AC-22), with the SwiftPM `.build` cache; SwiftLint [v1.1 | 2026-10-25]; Android build and unit tests; iOS build and unit tests (macOS runner); contract fixture checks; lint.
2. Merge to main: build the multi-stage image for `linux/amd64` (Swift toolchain image to build with `--static-swift-stdlib`, slim Ubuntu to run, non-root user), push it to GHCR as a public package tagged with the commit, run migrations (`DATABASE_MIGRATION_URL`) first, then call the staging service's Render deploy hook with the image tag (Render does not redeploy on push; migrations are forward-compatible, data-model.md section 8). [v1.1 | 2026-10-25]
3. Release tag `backend-vX.Y.Z`: operator approves, the same image digest is deployed to production through its deploy hook [v1.1 | 2026-10-25]. The image holds no secrets or data; all configuration comes from environment variables.
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
| Database | Neon free Postgres, Singapore (`aws-ap-southeast-1`): 1 GB, 100 CU-hours per month, suspend after 5 idle minutes, no expiry stated [v1.1 | 2026-10-25] | ADR-0002, ADR-0003 |
| TLS and domain | TLS by the host. `<API_HOST>` is the host-provided name during the trial; a custom domain is a launch cost to be decided before store release because the name is compiled into the apps (R-8) [v1.1 | 2026-10-25] | Owner approval |
| Backups | Encrypted dumps committed to a private GitHub repository `<BACKUP_REPO>` (free, no card) [v1.1 | 2026-10-25] | Section 6 |
| CI | GitHub Actions | |

Single instance, no autoscaling: expected peak is about 5 requests per second (architecture.md section 8). The free plan is for the trial only; real customers need the paid path (section 9).

## 6. Backup & Restore

| Item | Value |
| ---- | ----- |
| Method | Nightly `pg_dump` by a scheduled workflow using a read-only database role; output encrypted with `age` using a public key; pushed to a private GitHub repository by deploy key (a Cloudflare R2 bucket was not chosen: card requirement unverified) [v1.1 | 2026-10-25] |
| Frequency and retention | Every 24 hours; keep 14 daily and 8 weekly dumps (older files removed and history squashed periodically); Neon's own 6-hour restore window is an extra, not relied on; Render free has no backups [v1.1 | 2026-10-25] |
| Recovery point | 24 hours |
| Recovery time | 4 hours |
| Not allowed | Dumps as workflow artifacts of this public repository (artifacts of public repositories are readable by others, unverified) |
| Restore test | Required before launch and every 3 months: download one dump, decrypt with the offline private key, restore into a scratch database, run the reconciliation query (`day_load` equals the sum of cakes of non-cancelled orders), record the date in the operations log. A backup counts only after this test succeeds |

## 7. Observability

| What | How | Retention |
| ---- | --- | --------- |
| Logs | Structured JSON to stdout: time, level, request id, method, path, status, duration, platform, app version, error code. Never name, phone, address, note or body | 30 days at the host (estimate) |
| Health | Shallow `GET /healthz` (no database) is the only path the host health check and the external uptime monitor use, every 5 minutes. `GET /healthz?deep=1` (wakes the sleeping database) is for the operator and for deploy verification only [v1.2 | 2026-10-26] | |
| Metrics | From logs: requests, 5xx rate, p95 duration, orders created, 409 and 429 counts | |

Alerts (every alert has an owner and an action):

| Alert | Threshold | Told | Action |
| ----- | --------- | ---- | ------ |
| Health check fails | 2 consecutive failures (10 minutes) | Operator by email | Check host and database status; restart; roll back if after a release |
| 5xx rate | More than 5% of requests over 15 minutes | Operator | Read logs by request id; roll back |
| `POST /v1/orders` p95 over 8 s | 3 consecutive 5-minute windows | Operator | Likely database cold start or limits: consider the paid path (ADR-0003 upgrade path) [v1.1 | 2026-10-25] |
| Burst of 429 or orders | More than 50 `RATE_LIMITED` or 30 orders in 15 minutes | Operator, then owner | Check for abuse; set `ORDERING_ENABLED=false` if needed and tell the owner |
| Nightly backup failed | Workflow failure | Operator | Re-run; fix credentials; do not skip two nights |
| Database nearing free limit | Storage above 80% of 1 GB, or CU-hours above 80 in the month | Operator | Plan upgrade (owner approval) |

Cold starts on the free trial [v1.1 | 2026-10-25]: the Render service sleeps after 15 idle minutes and takes about 1 minute to wake; the Neon database suspends after 5 idle minutes and resumes in about 0.5 s to a few seconds (docs). The apps cope: the catalogue request at launch wakes the server; the 10-second order timeout leads to `ERR_TIMEOUT` and a same-key retry that creates one order. `/healthz` is shallow for monitors (no database query) so an uptime pinger never keeps the database awake or burns CU-hours; the database check is a separate `GET /healthz?deep=1` used by the operator and by deploy verification only: the staging smoke step in `backend.yml` calls it once per deploy, which resumes Neon for a few CU-seconds, an accepted cost; no monitor, alert or host check may use it [v1.2 | 2026-10-26]. The Render health-check path is set to `/healthz` (shallow; the setting is a platform console step, not verified here). An optional keep-warm ping of `/healthz` in business hours (07:00 to 22:00, about 450 hours per month) fits the 750 Render hours; whether Render's terms allow pings is unverified, so it is off by default.

## 8. Rollback

Backend:

1. Open the host's deploy history and redeploy the previous successful image (about 5 minutes).
2. If a migration ran, check whether it was an additive change: the previous version still works with it (data-model.md section 8). If a migration was destructive (should not be), restore from the last dump (section 6) and tell the owner about the lost orders window.
3. Verify `/healthz`, `GET /v1/catalog` and one test order on staging.
4. Record the incident in the operations log.

Mobile: halt the staged rollout in the store consoles and publish a fixed build; old app versions stay compatible because API `v1` is additive only (api.md section 6). A server change that breaks an app version is a defect.

Emergency stop of ordering: set `ORDERING_ENABLED=false` and restart; customers see `ERR_SERVER` and can contact the shop by Zalo or phone.

## 9. Cost Notes [v1.1 | 2026-10-25]

Running cost during the new-project phase: **USD 0** (ADR-0003). Figures are estimates from public pages read on 2026-10-25; confirm before purchase. Every paid item needs owner approval.

Trial (free):

| Item | Cost | Limit that matters |
| ---- | ---- | ------------------ |
| Render free web service | USD 0 | 750 hours, sleeps after 15 minutes, 5 GB bandwidth |
| Neon free Postgres | USD 0 | 1 GB, 100 CU-hours, suspends after 5 minutes |
| GitHub Actions, GHCR, private backup repository | USD 0 (public repository; unverified) | Fair-use limits |

Launch costs (listed, not decided here):

| Item | Estimate | Source |
| ---- | -------- | ------ |
| Apple Developer Program | USD 99 per year | Apple pricing, not fetched (unverified) |
| Google Play developer registration | USD 25 one time | Google pricing, not fetched (unverified) |
| Custom domain | About USD 10 to 15 per year | Not researched (unverified) |

Paid always-on path (when real customers order):

| Item | Estimate | Source |
| ---- | -------- | ------ |
| API instance always on (Render Starter) | About USD 7 per month | https://render.com/articles/how-much-does-cloud-application-hosting-cost-for-small-businesses (medium) |
| Neon paid plan with auto-suspend off | About USD 15 to 20 per month more (0.25 CU for 730 hours at about USD 0.106 per CU-hour, plus storage) | https://neon.com/pricing (medium, calculation) |
| Staging instance (optional) | About USD 7 per month more | Same as API instance |

## 10. Open Questions / Change log

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| DP-Q1 | Owner approval of costs in section 9 and hosting choice (ADR-0003) | Money, customer data | No | business | Closed for the trial (free plans, 2026-10-25); paid path needs approval later | Owner |
| DP-Q2 | Operator name and alert email | Alerts need an owner | Yes for launch | business | Open (owner) | |
| DP-Q3 | Is a staging environment wanted before launch | Free on the trial plans; paid later | No | business | Resolved for the trial: yes, free | Architect |

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version. |
| 1.1 | 2026-10-25 | Swift/Vapor image build in CI, GHCR and deploy hook, free trial hosting (Render, Neon), shallow and deep health checks, GitHub backup repository, costs restructured. |
| 1.2 | 2026-10-26 | After slice 0: CI files and runners, which health endpoint each consumer uses, `DATABASE_URL` optional locally, variables read only from later slices, sample-row warning moved to slice 4. |
