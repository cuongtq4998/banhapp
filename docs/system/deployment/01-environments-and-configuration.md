# Deployment and Operations: Environments, roles, configuration

Part of [deployment.md](../deployment.md) (index, version, change log), sections 1 to 3.1. Moved from deployment.md v1.8 with the wording unchanged unless a line carries a newer label [v1.9 | 2026-10-27].

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
| `PORT` | Listen port (Vapor binds `0.0.0.0` on it) | Yes for `serve`; not read by `migrate` [v1.4 | 2026-10-26] | Host |
| `DATABASE_URL` | Application database connection (limited role) | Yes in staging and production; optional when `APP_ENV=local` (the server then starts with the shallow health check only and logs a warning) [v1.2 | 2026-10-26] | Host secret store |
| `DATABASE_MIGRATION_URL` | Migration role connection | For migrations (`migrate` needs only this and `APP_ENV`; `serve` does not read it) [v1.4 | 2026-10-26] | CI secret, operator machine |
| `DATABASE_POOL_MAX` | Maximum connections per instance (default 5; free plans limit connections); direct, not pooled, connection string (ADR-0002) | No | Host |
| `SHOP_ID` | UUID of the shop served (single shop at launch) | Yes from slice 1 (not read by slice 0) [v1.2 | 2026-10-26] | Host |
| `TRUST_PROXY` | Read the client IP from the proxy header | Yes in staging and production from slice 1 (the read rate limit counts per address; without it every customer shares the proxy's address); not read by slice 0 [v1.7 | 2026-10-26] | Host |
| `ORDERING_ENABLED` | `true` or `false`; false returns 503 `ORDERING_PAUSED` | No (default true) | Host |
| `RATE_LIMIT_READ_PER_MINUTE` | Default 120; one shared budget per client address for `GET /v1/*`, `/healthz`, `/privacy`, `/assets/*` (api.md section 1) [v1.6 \| 2026-10-26] | No | Host |
| `RATE_LIMIT_ORDER_PER_HOUR` | Default 10 | No | Host |
| `ORDER_MAX_PER_PHONE_PER_DAY` | Default 5 | No | Host |
| `PUBLIC_ASSET_BASE_URL` | Prefix placed before `/assets/<image_path>` in `image_url` if assets move to another host (no trailing slash); empty by default, so `image_url` is relative to the API host. Image files live in `backend/assets/images/` and must be inside the image build context [v1.6 \| 2026-10-26] | No | Host |
| `LOG_LEVEL` | `info` default | No | Host |

Mobile build settings (per build configuration, not secrets): `API_BASE_URL` (staging, production). Android `usesCleartextTraffic=false`; iOS keeps App Transport Security defaults.

CI variables (names only) [v1.2 | 2026-10-26]: secrets `STAGING_DATABASE_MIGRATION_URL`, `STAGING_RENDER_DEPLOY_HOOK_URL`; variable `STAGING_BASE_URL`; the deploy job reads them from a GitHub environment named `staging` and skips itself with a notice while the secrets are unset. The test job uses throwaway credentials of a service container that exist only in the workflow. Backup variables: see auth.md section 5.

Startup warning for sample rows (ADR-0013): the check that logs a warning when `APP_ENV=production` and any row has `is_sample = true` is not in slice 0; it is built in slice 4 (launch readiness). Until then the launch checklist item below is the only guard [v1.2 | 2026-10-26].

### 3.1 Client address behind the host proxy [v1.7 | 2026-10-26]

Update [v1.8 | 2026-10-27]: the assumption "exactly one proxy" below is doubtful. The host's own articles state that inbound traffic to its web services passes through a CDN network and then the host's load balancers, and that the CDN appends to `X-Forwarded-For` (sources in ADR-0019); no reference page states how many entries reach the service. Until ADR-0019 is decided and the operator has run the verification on staging, treat the one-proxy rule as unproven. A wrong boolean only makes the limit too tight (all customers one key), not forgeable. ADR-0019 proposes `TRUST_PROXY_HOPS` instead of `TRUST_PROXY`.

- Assumption: exactly one proxy (Render's load balancer) sits between the customer and the API, and no CDN. With `TRUST_PROXY=true` the API counts the last entry of `X-Forwarded-For`: a proxy appends the address it saw and keeps what the client sent, so a client can forge only the entries before the last one. With two or more proxies the last entry is the inner proxy, not the customer.
- Source and confidence: Render's official documentation pages read on 2026-10-26 (https://render.com/docs/web-services; the load balancer terminates TLS and forwards to the service port) do not state how `X-Forwarded-For` is built. A Render staff reply in https://feedback.render.com/features/p/send-the-correct-xforwardedfor says Render sets the first IP in the list to the real client IP; a community thread (https://community.render.com/t/missing-x-forwarded-for-header-on-api-rewrites-to-backend/24481) reports that a client-sent header is kept and Render's view is appended. Both are consistent with "the last entry is the address Render saw" when no CDN is in front, but the exact behaviour is unverified in official documentation.
- Verification (operator, once on staging and once after any change of host or domain setup): call `GET /healthz` with `X-Forwarded-For: 203.0.113.9` from a known address and confirm in the access log (or a debug build) that the counted key is the caller's real address, not `203.0.113.9`. If it is the forged value, set `TRUST_PROXY=false` (the limiter then uses the connection address, too tight but safe) and raise it with atlas-architect.
- Failure direction: a wrong count makes the limit too tight (all customers share one budget; visible in the 429 alert), or, if the header were trusted wrongly, forgeable. Customer data is not involved.
- If a CDN or second proxy is added (for example Cloudflare in front of Render): the last entry becomes the CDN address, so all customers would share one budget. Required change in the same release: replace the boolean by a trusted proxy count `TRUST_PROXY_HOPS` (0 = connection address; n = the nth entry from the right) or read the CDN's client header, set from the real chain. Decision: not built now (one proxy, a single hosting plan; a CDN is a new cost and an owner decision, and would get its own ADR); the code comment in `ClientAddress` states the one-proxy assumption.
