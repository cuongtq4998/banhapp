# Admin Sign-in and Session Lifecycle

| Field        | Value |
| ------------ | ----- |
| Version      | 1.2 [v1.2 | 2026-10-31] |
| Last updated | 2026-10-31 |
| Status       | Draft |
| Owner        | atlas-architect |
| Based on     | product/admin-orders.md v1.4 (FR-1 to FR-7, FR-36, FR-37, FR-42, FR-43, FR-47, BR-5 to BR-8, BR-17, BR-26) |
| Related      | auth.md; api/05; data-model/04; ADR-0022, ADR-0023 |

## 1. Purpose & Scope

How a person signs in by e-mail code, how a device session lives, renews and ends, and how the owner recovers. Values and storage: auth.md and data-model/04.

## 2. Actors

Staff, owner, system (mail sender, maintenance task), operator (creates the first owner).

## 3. Main Flow: sign in

```mermaid
sequenceDiagram
    actor U as Person
    participant App
    participant API as Backend
    participant DB as PostgreSQL
    participant M as Mail provider
    U->>App: enters e-mail
    App->>API: POST /v1/auth/code-requests
    API->>DB: limits, auth_code row (real or phantom)
    API-->>App: 202 same body for every address
    API-)M: after response: send code if account is active
    U->>App: enters 6 digits
    App->>API: POST /v1/auth/sessions
    API->>DB: code check, session insert
    API-->>App: 201 access and refresh tokens
```

Steps: (1) request, limits first, then the row; (2) the mail is sent after the response; (3) verification: latest usable code (unused, fewer than 5 wrong entries, unexpired), HMAC compare, a wrong entry adds 1 to the code's `wrong_count`; (4) success consumes the code, decides whether the device is new (below), replaces an older session of the same installation, creates the session, writes a security event [v1.2 | 2026-10-31]; (5) owner only, device new: the new-device notice is sent after the response (FR-47, BR-26): to the owner address and the confirmed backup address, with device name and time, no code or link; one retry after 5 s; a failure is logged and never affects the sign-in. "New" means no unrevoked, unexpired session of the owner account has this `installation_id` when the code is accepted (ADR-0022). Staff, renewals, recovery and review sign-ins send nothing. First owner: the operator runs `bootstrap-owner` (A-2).

## 4. Alternate & Error Flows

| Case | Handling | Trace |
| ---- | -------- | ----- |
| Unregistered or inactive address | Same 202 and same later errors; phantom row, no mail | FR-1, AC-2 |
| Resend before 30 s, fourth code in an hour, daily or per-address cap | 429 `CODE_RESEND_WAIT` or `CODE_REQUEST_LIMIT` with seconds (ordinary and recovery counted separately) | FR-3, FR-6, AC-6, AC-9 |
| Wrong code (fifth) | The 5th wrong entry voids the code: 422 `CODE_EXPIRED` ("request a new code"), also for its correct digits later; no time lock; a new code after 30 s starts a fresh count of 5 | AC-8, AC-77 | [v1.2 | 2026-10-31]
| Code older than 10 minutes or used | `CODE_EXPIRED` or `CODE_INVALID`; a new code makes older ones invalid | AC-4, AC-5, AC-6 |
| Mail provider failure | Logged without the address; the person requests a new code | FR-1 |
| Refresh response lost | Retry with the old refresh token within 20 s returns a new pair | FR-36 |
| Old refresh token replayed later | Whole session revoked (`reuse_detected`), 401 `SESSION_REVOKED` | FR-36, AC-54 |
| Owner revokes a device or deactivates an account | Session rows revoked at once; the next request is refused; renewal impossible | FR-7, FR-37, AC-14, AC-55 |
| Mail service fails when sending the new-device notice | Sign-in succeeds; failure logged without addresses | FR-47, AC-95 |
| Owner without a backup address starts recovery | 202, nothing sent; no information given | FR-43, AC-59 |
| Sign-out while offline [v1.1 | 2026-10-31] | App clears data and shows sign-in at once; keeps a pending sign-out (refresh token only), unregisters the push token locally, repeats refresh then `DELETE /v1/admin/session` when online, for 7 days at most | FR-35, AC-11 |

## 5. State Machine (device session)

```mermaid
stateDiagram-v2
    [*] --> Active: sign-in or recovery
    Active --> Active: refresh (restarts 7 days)
    Active --> Revoked: sign-out, owner revoke, deactivation, reuse, replaced
    Active --> Expired: 7 days without refresh
    Revoked --> [*]
    Expired --> [*]
```

| From | To | Trigger | Actor | Guard | Side effects |
| ---- | -- | ------- | ----- | ----- | ------------ |
| (none) | Active | Correct code (or both recovery codes) | Person | Account active, code usable (not void) | Tokens issued, older session of the installation revoked, security event, push token not yet set |
| Active | Active | `POST /v1/auth/refresh` | Device | Current hash, or previous hash within 20 s | New hashes, `refresh_expires_at` = now + 7 days, previous hash kept |
| Active | Revoked | Sign-out | Person | Own device | Push token deleted |
| Active | Revoked | Revoke | Owner (any), staff (own) | Device exists | Push token deleted; event |
| Active | Revoked | Deactivation | Owner | Target is staff | All sessions of the account, tokens deleted, same transaction |
| Active | Revoked | Reuse | System | Old hash after the grace | Event `refresh_reuse_detected` |
| Active | Expired | Clock | System | `refresh_expires_at` passed | Cleanup after 30 days |

Final states: Revoked, Expired. A request is served only for Active sessions of active accounts with an unexpired access token.

## 6. Recovery flow

Ordinary owner sign-in is not this flow: it is the flow of section 3 with one code to the owner address, with or without a backup address (owner decision 2026-10-31) [v1.1 | 2026-10-31]. Recovery is optional and separate; auth.md section 2 states what it protects and what it does not.

Owner enters the owner address on the recovery screen; the server creates two codes in one challenge when a confirmed backup address exists, sends one to each mailbox, and the owner types both. Success creates a session, notifies both addresses and offers the device list. A wrong entry adds 1 to both codes of the challenge; the 5th voids the attempt and both codes; a new attempt can be requested after 30 s; recovery counters are separate from ordinary sign-in in both directions [v1.2 | 2026-10-31]. Backup address registration and change use the same code table with purpose `backup_confirm` (FR-42). A recovery sign-in sends its own notice to both mailboxes and no new-device notice.

## 7. Business Rules Applied

BR-5 (code, limits, void after 5 wrong): auth/abuse-secrets-threats.md 4.2. BR-6 (7 days, renewal, reuse): section 5 above. BR-7 (addresses): data-model/04 triggers. BR-8 (30 staff, owner protected, 5 minutes): triggers and per-request session check. BR-17 (recovery): section 6. BR-26 (new-device notice): section 3, step 5.

## 8. Concurrency & Idempotency

Two refreshes at once with the same token: the row update is conditional on the presented hash; the loser repeats the lost-response path inside the grace window. Two sign-ins with the same code: the consume update is conditional (`consumed_at IS NULL`); one wins. Deactivation and sign-in racing: the session insert checks `is_active` in the same statement.

## 9. Events & Audit

`security_event` rows for sign-in, recovery, sign-out, revoke, reuse, backup change (account changes are in `settings_change`); no address and no code stored.

## 10. Open Questions / Change log

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| SL-Q1 | May the owner sign in on any device with one code (as staff do), or only with two codes? | Business behaviour of the powerful account | No | business | Closed 2026-10-31: ALWAYS one code; two-code recovery stays a separate flow | Owner |
| SL-Q2 | Notice to the backup and owner address on an owner sign-in from a new device | Tripwire for a mailbox takeover | No | business | Closed 2026-10-31 (Q-24): yes, designed in section 3 step 5 and ADR-0022 | Owner |

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version. |
| 1.1 | 2026-10-31 | SL-Q1 closed by the owner (one code), SL-Q2 opened, offline sign-out row, recovery separated from ordinary sign-in. |
| 1.2 | 2026-10-31 | Aligned with PRD v1.4: 5th wrong entry voids the code, no time lock, recovery counters separate, new-device notice (TQ-11, TQ-13); SL-Q2 closed. |
