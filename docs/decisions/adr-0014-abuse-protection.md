# ADR-0014: Abuse protection for anonymous ordering

| Field    | Value |
| -------- | ----- |
| ADR      | 0014 |
| Status   | Accepted (the per-phone daily limit is a default that the owner may change; see report). Slice 1 limits amended by ADR-0017 and ADR-0019 [v1.1 | 2026-10-27] |
| Date     | 2026-10-25 |
| Decider  | atlas-architect |
| Based on | PRD BR-7, BR-1, G-2; standard 07 rule 4 |

## Context

Orders need no account and no phone verification (a one-time code costs money and is not in this slice). An attacker or a prankster could fill a date's capacity with fake orders, flood the database, or probe the API. The API is public; a mobile app cannot keep a secret.

## Decision Drivers

- Protect capacity (the shop's real constraint) and the free database limits.
- No cost, no extra friction for honest customers.
- Simple to operate.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Rate limits per IP and per phone number, request size limits, an `ORDERING_ENABLED` switch | Free; simple; effective against casual abuse | Shared mobile IPs may hit the IP limit; a determined attacker can rotate IPs and phones |
| B. SMS verification of the phone number | Strong proof of a real number | Costs money per SMS; changes customer journey (PRD); needs owner approval |
| C. App attestation (Apple App Attest, Play Integrity) | Blocks non-app clients | Extra complexity and service quotas; not needed at launch (unverified details) |
| D. CAPTCHA | Blocks bots | Bad mobile UX; not in the UI specification |

## Decision

Option A for this slice (numbers in auth.md section 5): per-IP limits on all `/v1` routes and a tighter limit on `POST /v1/orders`; at most 5 orders accepted per normalised phone number in 24 hours (configuration `ORDER_MAX_PER_PHONE_PER_DAY`); body limit 8 KB; the owner can turn ordering off with `ORDERING_ENABLED=false` (503 `ORDERING_PAUSED`). The shop sees every order and contacts the customer (A-4), which is the human check. Options B and C are recorded as the upgrade path if abuse appears; B needs owner approval because it costs money (standard 07 rule 4).

## Amendment [v1.1 | 2026-10-27]

The text above is the slice 0 decision. What is built and what changed since:

- Reads: one shared budget of 120 requests per minute per client address for every `GET` and `HEAD` route including `/healthz`, `/privacy` and `/assets/*` (ADR-0017 item 2; api.md section 1; auth.md section 4), not "per-IP limits on all `/v1` routes".
- `POST /v1/orders`: 10 per hour per address; built in slice 3 (not yet).
- The per-phone limit (5 accepted orders per normalised phone per 24 hours, `ORDER_MAX_PER_PHONE_PER_DAY`) is **not built yet**; slice 3. It is the only limit that survives a restart and a client address change, because it is counted in the database.
- The limiter is in memory, one process: it **resets on every restart and on every wake from the free plan's sleep** (R-1), so the first minute after a wake has a fresh budget for everyone. The earlier sentence "the per-phone limit is in the database" is true only from slice 3.
- A fixed 60-second window per address allows up to twice the limit across a window boundary (a burst at the end of one window and the start of the next). Accepted at this size; a sliding window is not worth the code.
- The address that is counted depends on the proxy trust model: ADR-0019.

## Consequences

- Positive: free, quick to build, testable by request cases.
- Negative: not proof against a determined attacker; an in-memory limiter resets when the single instance restarts (acceptable, the per-phone limit is in the database).
- Follow-up: alert on a burst of 429 and of orders (deployment.md section 7).

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Anonymous endpoints are abuse targets; rate limiting is the standard first control | OWASP API Security Top 10 (unrestricted resource consumption), not fetched | 2026-10-25 | Unverified |
| SMS costs money per message | Standard 07 rule 4 | 2026-10-25 | High |

## Links

Related: ADR-0008, ADR-0017 (read limit), ADR-0019 (client address). Detail: docs/system/auth.md.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version (Accepted). |
| 1.1 | 2026-10-27 | Amendment: real limits, per-phone limit not built, in-memory reset, window burst, pointers to ADR-0017 and ADR-0019. |
