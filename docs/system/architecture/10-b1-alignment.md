# System Architecture: Slice B1 alignment, dropped and deferred items, review findings

Part of [architecture.md](../architecture.md) (index, version, change log), section 26. New in v1.14 [v1.14 | 2026-11-01]. Slice B1 (sign-in, sessions, role gate) is built; where the code or an owner direction was the better choice the system documents now follow it. Sources: `backend/Sources/App/Routes/Admin`, `Services/Admin`, `backend/db/migrations/0002_admin_auth.sql`.

## 26.1 Decisions

| Topic | Rule | Written in |
| ----- | ---- | ---------- |
| Names | Operator command `create-owner --email <EMAIL> [--name <NAME>]`; variables `AUTH_CODE_PEPPER`, `EMAIL_PROVIDER`, `EMAIL_MAX_PER_DAY` (the live provider's variables are `EMAIL_API_KEY`, `EMAIL_FROM_*`, later) | deployment/04, auth.md, architecture/07 |
| Sign-in switch | Both `AUTH_CODE_PEPPER` and `EMAIL_PROVIDER` unset: sign-in OFF, `/v1/auth/*` answers 503 `SERVICE_UNAVAILABLE`, the customer API is unaffected, existing deployments keep working. Only one set: start refused. `console` and `recording` providers are refused in production | deployment/04 section 11, api/05 |
| Refresh grace | 20 s from the FIRST rotation. A retry inside the window rotates again but keeps the stored time and the stored previous hash. Safer than a sliding window: repeated retries never extend the time in which a stolen old token works (at most 20 s in total) | api/05 10.3, session-lifecycle |
| `Retry-After` | Always the real wait, capped at 3600 s (`APIError.maxRetryAfterSeconds`). The daily mail cap resets at 00:00 UTC and may be up to 24 h away: the answer says at most 3600 and the app asks again after that. Simple, one cap, no special case | api/05 10.1, api/08 |
| New device (R-12) | One rule: the owner has no unrevoked, unexpired session with this `installation_id` when the code is accepted. Sign out then in again on the same phone sends a notice; a renewal does not. PRD wording to use: "a phone on which the owner has no signed-in session at that moment" | session-lifecycle, ADR-0022 |
| Tokens | `device_id` in JSON is upper-case (database uuid text); tokens embed it lower-case and only the lower-case form parses. Clients compare `device_id` case-insensitively | api/05 10.2 |

## 26.2 Not built in B1: dropped or deferred

| Item | Decision | Reason |
| ---- | -------- | ------ |
| Per-session limit 240 a minute (`RATE_LIMIT_ADMIN_PER_MINUTE`) | Dropped | At most 31 accounts; the PRD asks for no such limit; requests are authenticated, so abuse is limited to a known account |
| 401 limit 60 a minute per client address | Dropped | Token secrets are 256 bits, guessing is not feasible; the `/v1/auth` limits (20 and 60 an hour) stay, fixed in code |
| `last_used_at` periodic write | Dropped | Nothing reads it; expiry uses `refresh_expires_at`. The column stays with its default |
| Store review account and `review-account on/off` (ADR-0027) | Deferred to the launch slice A6 | Needed only for store submission, which waits for the money approvals (DP-Q4) |
| `PUT /v1/admin/push-token` | Deferred to the push slice | FR-25 and FR-26 are built there with the push sender |
| Purge task (codes, sessions, security events) | Deferred to slice B2, and a go-live gate item; NOT built in B2 or B3 either (architecture/11 section 27.2) [v1.15 \| 2026-11-01] | `auth_code` rows hold addresses; harmless on the free staging host with fake data, not for real staff |

## 26.3 Review findings owned by the architect (test plan 08)

| ID | Status | Resolution |
| -- | ------ | ---------- |
| R-1 | Fixed | Repeating the close of an old order after it left the window answers 200 `Idempotent-Replay`; any other call on an order outside the window is 404 (ADR-0028 v1.3, api/06 10.11). To implement in the orders slice; TC-B68, C23, C38 expect the replay |
| R-12 | Fixed | One rule, see 26.1. Query for the requirements agent: align FR-7, BR-13, AC-12 to the PRD wording above |
| R-14 | Already fixed | ADR-0029 v1.1 and api/06 10.9: keyset on four immutable columns, refresh from page 1 |
| R-16 | Already fixed | ADR-0025 v1.1 and api/05: 5,242,880 bytes, route body limit 5,308,416, HEIC converted on the phone and refused by signature on the server |
| R-4 to R-8, R-10 | Already fixed | Resolved by the v1.16 simplification (api/05 to 08, data-model/04) |
