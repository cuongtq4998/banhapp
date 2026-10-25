# Authentication and Authorization

| Field        | Value |
| ------------ | ----- |
| Version      | 1.1 |
| Last updated | 2026-10-25 |
| Status       | Draft |
| Owner        | atlas-architect |
| Based on     | product/place-order.md v1.2 (BR-7); api.md v1.0 |
| Related      | ADR-0014; architecture.md; data-model.md |

Scope: only what the customer ordering slice needs. Staff and owner login by phone number with a one-time code is a later slice and is a placeholder here (sections 2 to 4).

## 1. Actors & Roles

| Actor | Identity | In this slice |
| ----- | -------- | ------------- |
| Anonymous customer | None; an order holds name, phone, address (BR-7) | Yes |
| Staff | Phone number and one-time code (later) | Placeholder, no endpoint |
| Owner | Same as staff with configuration rights (later) | Placeholder, no endpoint |
| System | Backup job, migration runner, purge job (later) | Uses database credentials; not an API caller |

## 2. Authentication

Customer: none. There is no login, token or session (BR-7, Apple guidance cited in PRD S-2). The apps carry no secret and no API key, because a secret inside a public mobile app can be extracted; protection is by rate limits (section 4) and server-side validation.

Staff (placeholder, not designed here): login by phone and one-time code; short-lived access token and revocable refresh token; only hashes of codes and refresh tokens are stored (standard 07 rule 2); responses must not reveal whether a number belongs to staff (rule 3); SMS costs money and needs owner approval (rule 4). Paths are reserved under `/v1/staff`.

## 3. Authorization

| Endpoint group | Anonymous | Staff | Owner |
| -------------- | --------- | ----- | ----- |
| `GET /v1/catalog`, `GET /v1/availability` | Allowed | Allowed | Allowed |
| `POST /v1/orders` | Allowed (rate limited) | Allowed | Allowed |
| `GET /healthz`, `/privacy`, `/assets/*` | Allowed | Allowed | Allowed |
| `/v1/staff/*` (later) | Denied (401) | By role (later) | By role (later) |

Authorization is enforced by the server. In this slice there is no endpoint that reads an order back, so no customer data can be read through the API. The database role used by the backend has only the rights the slice needs (no schema changes at run time; migrations use a separate role).

## 4. Abuse Protection (ADR-0014)

| Control | Value (configuration default) |
| ------- | ----------------------------- |
| Read requests per IP | 120 per minute, then 429 |
| `POST /v1/orders` per IP | 10 per hour, then 429 |
| Accepted orders per normalised phone number | 5 per 24 hours (`ORDER_MAX_PER_PHONE_PER_DAY`), then 429 `RATE_LIMITED` |
| Request body size | 8 KB, then 413 |
| Ordering switch | `ORDERING_ENABLED=false` returns 503 `ORDERING_PAUSED` |
| Repeat requests | `Idempotency-Key` (api.md 4.3); a replay is not counted again |
| Client IP | From the trusted proxy header set by the host (`TRUST_PROXY=true`); never from client-supplied values when the proxy is absent |
| Lockouts | None for customers (no login attempts exist) |
| Timing and responses | Error bodies never contain stack traces, SQL or personal data |

No SMS or other paid verification is used. If abuse appears the upgrade path is SMS verification (needs owner approval, costs money) or app attestation (ADR-0014).

## 5. Secrets & Key Handling

Names only; values live in the host's secret store and local `.env` files (not committed).

| Secret | Purpose | Where |
| ------ | ------- | ----- |
| `DATABASE_URL` | Application database connection (limited role) | Host secret store |
| `DATABASE_MIGRATION_URL` | Migration role connection | CI and operator machine only |
| `BACKUP_DATABASE_URL` | Read-only role for dumps | CI secret store |
| `BACKUP_AGE_PUBLIC_KEY` | Encrypts dumps (public key, not secret, but environment-specific) | CI variable |
| `BACKUP_REPO_DEPLOY_KEY` | Push encrypted dumps to the private backup repository (write access to that repository only) [v1.1 | 2026-10-25] | CI secret store |
| Backup decryption private key | Restore | Owner's offline password manager, never in the host or the repository |
| Container image on GHCR | Public package; contains no secrets or data (ADR-0003) [v1.1 | 2026-10-25] | Registry |
| `RENDER_DEPLOY_HOOK_STAGING`, `RENDER_DEPLOY_HOOK_PRODUCTION` | Anyone with the URL can trigger a deploy [v1.1 | 2026-10-25] | CI secret store |
| Later: SMS provider key, token signing key | Staff login | Host secret store |

Rotation: database passwords on staff change or suspected leak; at least once a year (recommendation).

## 6. Threat Notes

| Threat | Mitigation |
| ------ | ---------- |
| Fake orders fill a date's capacity | Rate limits per IP and phone; the shop contacts every customer (A-4); ordering switch; alert on bursts |
| Capacity oversell by races | Database-enforced counter (ADR-0008) |
| Duplicate orders from retries | Idempotency key |
| Tampered prices or totals | Server computes everything; client total is only an acknowledgement |
| SQL injection | Parameterised queries only; schema validation of all input |
| Personal data in logs | Log policy: no name, phone, address or note; request ids only |
| Leak of personal data from backups | Dumps encrypted with a public key; private key offline; storage private |
| Enumeration of orders | No read endpoint; codes are random (ADR-0009) |
| Data in transit | HTTPS only; the apps allow no cleartext traffic (iOS App Transport Security default, Android `usesCleartextTraffic=false`) |
| Draft left on a lost phone | App-private storage, device encryption, 24 hour expiry, excluded from backups (ADR-0011) |
| Cross-origin web abuse | No browser clients; CORS disabled |

## 7. Open Questions / Change log

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| AU-Q1 | Is the per-phone limit of 5 orders per 24 hours acceptable to the shop? | Visible limit on repeat customers | No | business | Default applied; owner may change | |

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version (customer slice; staff login placeholder). |
| 1.1 | 2026-10-25 | Backup storage secret replaced by a deploy key; deploy hook secrets; public image note. |
