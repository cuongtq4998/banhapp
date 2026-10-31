# Authentication: Abuse protection, secrets, threats

Part of [auth.md](../auth.md) (index, version, change log), sections 4 to 7. Customer rows are moved from auth.md v1.5 unchanged unless a line carries a newer label; admin rows are new [v2.0 | 2026-10-31].

## 4. Abuse Protection

### 4.1 Customer (ADR-0014)

| Control | Value (configuration default) |
| ------- | ----------------------------- |
| Read requests per IP | 120 per minute in one shared budget (all read routes and static files; 304 and 404 count, a 429 does not), then 429 with `Retry-After` |
| `POST /v1/orders` per IP | 10 per hour, then 429 with `Retry-After`; a global middleware that runs before the body is read and before the idempotency lookup, so a replay counts and a 429 does not |
| Counted orders per normalised phone number | 5 per 24 hours (`ORDER_MAX_PER_PHONE_PER_DAY`), then 429 `RATE_LIMITED` with `Retry-After` 3600. Counts stored orders that are not cancelled, plus orders cancelled with reason `fake_spam`; check, then insert, so a burst can slip a few past the limit (the cake capacity stays exact, ADR-0008); survives restarts. Owner decision Q-12, answers Place Order Q-O3 (ADR-0030) [v2.0 \| 2026-10-31] |
| Request body size | 8 KB, then 413 (admin cake upload: 5 MB + 64 KB on that route only) |
| Ordering switch | `ORDERING_ENABLED=false` returns 503 `ORDERING_PAUSED` |
| Repeat requests | `Idempotency-Key`; a replay is not counted by the per-phone limit but is counted by the per-IP limit |
| Client IP | From the trusted proxy header (`TRUST_PROXY=true`, one proxy assumed); ADR-0019 (Proposed) replaces it by a verified hop count |
| Lockouts | None for customers |
| Responses | Error bodies never contain stack traces, SQL or personal data |

No SMS or other paid verification is used (ADR-0014).

### 4.2 Admin sign-in (ADR-0022, ADR-0023) [v2.0 | 2026-10-31]

All limits apply to registered and unregistered addresses alike. None relies on the client address being right (ADR-0019 open); the address and global keys come first, the client address is an extra.

| Control | Value |
| ------- | ----- |
| Code lifetime | 10 minutes, one use |
| Wait between codes | 30 s per address (`CODE_RESEND_WAIT`) |
| Codes per address | 3 per rolling hour (`CODE_REQUEST_LIMIT`); one purpose, sign-in [v2.3 | 2026-10-31] |
| Wrong codes | 5 wrong entries void the current code (counted on the code, `auth_code.wrong_count`); the right digits of a void code are refused (`CODE_EXPIRED`, request a new one); no time lock on the address; a stranger gets at most 15 guesses an hour per address (Q-20, BR-4) [v2.3 | 2026-10-31] |
| Code requests per client address | 20 per hour (in memory, resets on restart; extra only) [v2.3 | 2026-10-31] |
| Other `/v1/auth` routes per client address | 60 per hour for sessions and refresh together (`RATE_LIMIT_AUTH_PER_HOUR_IP`); unauthenticated requests to `/v1/admin` and `/v1/owner` that answer 401 count 60 per minute per client address (stops token guessing). In memory, extra only (R-6) [v2.1 \| 2026-10-31] |
| Global mail cap | `MAIL_MAX_PER_DAY` default 80 per UTC day; above it requests answer as `CODE_REQUEST_LIMIT` and no mail is sent (protects the provider quota; it can be used to block sign-in for a day, risk R-AO-2) |
| Refresh | Shared admin limit; reuse detection of auth.md section 2 |
| Signed-in routes | 240 requests per minute per device session |
| Cake upload | Owner only; 5 MB; 30 uploads per hour per account |
| Notices | An owner sign-in on a new phone sends one notice to the owner address (no code); not counted in the daily cap (ADR-0022) [v2.3 | 2026-10-31] |

## 5. Secrets & Key Handling

Names only; values live in the host's secret store and local `.env` files (not committed).

| Secret | Purpose | Where |
| ------ | ------- | ----- |
| `DATABASE_URL` | Application database connection (limited role) | Host secret store |
| `DATABASE_MIGRATION_URL` | Migration role connection | CI and operator machine only |
| `BACKUP_DATABASE_URL` | Read-only role for dumps | CI secret store |
| `BACKUP_AGE_PUBLIC_KEY` | Encrypts dumps (public key, environment-specific) | CI variable |
| `BACKUP_REPO_DEPLOY_KEY` | Push encrypted dumps to the private backup repository | CI secret store |
| Backup decryption private key | Restore | Owner's offline password manager, never on the host or in the repository |
| Container image on GHCR | Public package target; contains no secrets or data (ADR-0003 v1.3) | Registry |
| `RENDER_DEPLOY_HOOK_STAGING`, `RENDER_DEPLOY_HOOK_PRODUCTION` | Anyone with the URL can trigger a deploy | CI secret store |
| `AUTH_CODE_PEPPER` | Keyed hash of sign-in codes; rotate only with all open codes expiring (10 minutes) [v2.0 \| 2026-10-31] | Host secret store |
| `MAIL_API_KEY` | Mail provider (ADR-0023) | Host secret store |
| `APNS_PRIVATE_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID` | Apple push (ADR-0024) | Host secret store |
| `FCM_SERVICE_ACCOUNT_JSON` | Google push (ADR-0024) | Host secret store |
| `REVIEW_ACCOUNT_CODE` | Store review account, set only during review (ADR-0027) | Host secret store |
| Test code switch `AUTH_FIXED_CODE` | Fixed code for automated tests; the app refuses to start with it when `APP_ENV=production` | Local and staging environment only |

Access and refresh tokens are not configured secrets: they are random per session and stored only as hashes. Rotation: database passwords on staff change or suspected leak, at least once a year; provider keys when a person with access leaves; the APNs key does not expire but is revoked in the Apple account if leaked (unverified).

## 6. Threat Notes

| Threat | Mitigation |
| ------ | ---------- |
| Fake orders fill a date's capacity | Rate limits per IP and phone; the shop contacts every customer; ordering switch; alert on bursts |
| Capacity oversell by races | Database-enforced counter (ADR-0008) |
| Duplicate orders from retries | Idempotency key |
| Tampered prices or totals | Server computes everything |
| SQL injection | Parameterised queries only; schema validation of all input; search text escaped for `LIKE` |
| Personal data in logs | Log policy: no name, phone, address, note, e-mail, token or code; request ids only |
| Leak of personal data from backups | Dumps encrypted; private key offline; storage private |
| Enumeration of orders | Customer: no read endpoint, random codes. Admin: orders readable only by active signed-in accounts, window 90 days, 404 for unknown and out-of-window alike |
| Data in transit | HTTPS only; no cleartext traffic in either app |
| Draft left on a lost phone | App-private storage, 24 hour expiry, excluded from backups (ADR-0011) |
| Cross-origin web abuse | No browser clients; CORS disabled |
| Guessing a 6-digit code | 5 wrong entries void the code; 3 codes an hour, so at most 15 guesses an hour per address; HMAC with a server secret; 10-minute life |
| Mail flooding of a third party | 30 s wait, 3 an hour per address, global cap; mail only to registered active addresses |
| Account enumeration | Same response, timing and later errors for unknown addresses (phantom rows, mail after response) |
| Locking an account out by wrong codes | No lock exists (Q-20): a stranger can only void codes and use the hourly requests; signed-in devices are unaffected, the operator can recover (A-7) |
| Stolen refresh token | Rotation; reuse revokes the session; "Sign out all other phones"; sign-in restarts on use with no absolute cap (owner decision Q-15; R-AO-4) |
| Lost phone | "Sign out all other phones" from another phone (own account) or, for staff, the owner switches the account off; customer data cleared at sign-out; Keychain or Keystore storage; device passcode [v2.3 | 2026-10-31] |
| Owner mailbox compromised | Not prevented: ordinary owner sign-in needs one code (Q-18). Mitigation: the notice to the owner address on sign-in from a new phone (Q-24) and "Sign out all other phones"; mailbox loss is recovered by the operator (A-7) [v2.3 | 2026-10-31] |
| Privilege escalation | `RequireRole` per group, service re-check; tests with staff tokens on every owner route |
| Customer data in push | Payload holds code, cakes, date only |
| Malicious image upload | Signature and dimension checks, size cap, owner-only, served with fixed content type and `nosniff` (ADR-0025) |
| Review account abuse | Demo rows only, no push, removed after review (ADR-0027) |
