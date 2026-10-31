# System Architecture: Admin simplification, Unfinished view, new-device notice

Part of [architecture.md](../architecture.md) (index, version, change log), section 25. New in v1.12 [v1.12 | 2026-10-31]. Owner directive of 2026-10-31: every user type must find workflows and rules easy and the apps must stay simple; the same applies to the system. Decisions: ADR-0022 v1.2, ADR-0029 v1.2.

## 25.1 Answers to the PRD technical questions

| ID | Answer | Written in |
| -- | ------ | ---------- |
| TQ-11 | Attempts are counted on the code (`auth_code.wrong_count`); 5th wrong entry voids it; no address lock; limits are per address and purpose, so recovery is separate; BR-23 boundaries hold as written (`now < expires_at`, 30 s allowed at exactly 30, hourly look-back 60 minutes, 7 days exactly needs a code, 90 days exactly still shown) | ADR-0022 v1.2; data-model/04 3.12; api/05 |
| TQ-12 | One endpoint (`GET /v1/admin/orders?view=unfinished`), `unfinished_count` on every list response, one tiny partial index, no cache or counter table. Old unfinished orders pass the window function for detail and status change only; search, default list and counts keep the strict 90 days. Banner is client-only | ADR-0029 v1.2; api/06 10.9 to 10.11 |
| TQ-13 | New = no unrevoked, unexpired session of the owner with the same `installation_id` at the moment the code is accepted. Notice sent after the response by the existing mail task, one retry, failure logged and ignored, no table | ADR-0022 v1.2; session-lifecycle.md section 3 |

## 25.2 What was simplified (v1.12)

| Before | After | Why it is safe |
| ------ | ----- | -------------- |
| Table `auth_email_state` (lock, counter) | Removed; `auth_code.wrong_count` | PRD has no lock (Q-20); one table, no reset or purge logic |
| Table `push_token` (1 to 1 with a session) | Two columns of `device_session` | Same rule (one token per device); no join, no cascade |
| Error `CODE_LOCKED` and its UI text with minutes | Removed; the void code answers `CODE_EXPIRED` | One message "request a new code" covers expired and void |
| `security_event` types: account added, deactivated, reactivated, code lockout | Removed | `settings_change` already records account changes; no lock any more |
| `device_session.app_version` | Removed | Never shown or queried; `X-App-Version` header stays |
| Shared counters of ordinary and recovery codes | Per purpose counters | Same code path, no cross-block, nothing extra to build |
| Separate Unfinished endpoint and count endpoint (the obvious design) | One query parameter and one field | Reuses list code, cursor and index |
| New-device notice via outbox or table | Mail task after the response | A lost notice only loses a tripwire; sign-in never depends on it |
| Counts | Admin tables 5 (was 7); admin endpoints unchanged in number (the Unfinished view added none); error codes 1 fewer; new ADRs 0 | |

Kept on purpose, with the reason: three route prefixes `/v1/auth`, `/v1/admin`, `/v1/owner` (one `RequireRole` per group is simpler than per-route checks; staff already get 403 on `/v1/owner`); the 20 s refresh grace and rotation (owner accepted, ADR-0022); `previous_refresh_hash` and `refresh_rotated_at` (needed by the grace); `settings_change` (FR-30); the `/impact` preview (BR-10 requires it); the 11 admin ADRs (each is a separate, small decision; merging would only renumber references).

## 25.3 Dropping deferred features without rework

The PRD simplification may defer recovery with backup e-mail, device management and push settings. Each is a closed group that nothing else depends on.

| Feature | Drop by removing | Left untouched |
| ------- | ---------------- | -------------- |
| Recovery and backup e-mail (FR-42, FR-43, BR-17, FR-47 backup copy) | Endpoints `recovery-requests`, `recovery-sessions`, `PUT /v1/owner/backup-email`, `.../confirmation`; purposes `recovery_owner`, `recovery_backup`, `backup_confirm`; `challenge_id`; `account.backup_email*`; `sign_in_method = recovery`; event `backup_email_changed`; the new-device notice then goes to the owner address only | Ordinary sign-in, sessions, `wrong_count`, all orders |
| Device management (FR-37) | `GET /v1/admin/devices`, `DELETE /v1/admin/devices/{id}`. Sign-out and deactivation still revoke sessions. Revocation then happens only by deactivating (staff) or operator action (owner); the new-device notice loses its "revoke it in the list" advice | `device_session` and the new-device rule (it reads the same rows) |
| Push settings (FR-34 hint, token removal) | `DELETE /v1/admin/push-token`. `PUT` stays; sign-out and revoke already clear the token | Push sending |
| Unfinished banner (FR-51) | Nothing on the server | Badge, chip, view |

## 25.4 Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version of this part (architecture.md v1.12). |
