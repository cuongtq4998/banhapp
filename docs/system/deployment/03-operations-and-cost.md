# Deployment and Operations: Backup, observability, rollback, cost

Part of [deployment.md](../deployment.md) (index, version, change log), sections 6 to 9. Moved from deployment.md v1.8 with the wording unchanged unless a line carries a newer label [v1.9 | 2026-10-27].

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
