# System Architecture: Admin simplification and the list of deleted items

Part of [architecture.md](../architecture.md) (index, version, change log), section 25. New in v1.12 [v1.12 | 2026-10-31]; updated in v1.13 for the simplified PRD v1.6 (27 FR, 14 BR; mapping in `product/admin-orders/08-deferred-and-id-mapping.md` section 15) [v1.13 | 2026-10-31]. Owner directive of 2026-10-31: every user type must find workflows and rules easy and the apps must stay simple; the same applies to the system. Decisions: ADR-0022 v1.3, ADR-0029 v1.3, ADR-0030 v1.1, ADR-0024 v1.3.

## 25.1 Answers to the PRD technical questions

| ID | Answer | Written in |
| -- | ------ | ---------- |
| TQ-11 | Attempts are counted on the code (`auth_code.wrong_count`); 5th wrong entry voids it; no address lock; limits are per address; BR-4 boundaries hold as written (`now < expires_at`, 30 s allowed at exactly 30, hourly look-back 60 minutes, 7 days exactly needs a code, 90 days exactly still shown) | ADR-0022 v1.3; data-model/04 3.12; api/05 |
| TQ-12 | SUPERSEDED in v1.13 [v1.13 \| 2026-10-31]. There is no Unfinished view, no `view` parameter and no banner. One list endpoint; the default "To do" list holds all New and Confirmed orders of any age. One window predicate everywhere: open orders always, finished orders 90 days after they were placed. `unfinished_count` (badge) stays on the list response; one tiny partial index; no cache or counter table | ADR-0029 v1.3; api/06 10.9 |
| TQ-13 | New = no unrevoked, unexpired session of the owner with the same `installation_id` at the moment the code is accepted. Notice to the owner address only, sent after the response by the existing mail task, one retry, failure logged and ignored, no table | ADR-0022 v1.3; session-lifecycle.md section 3 |

## 25.2 What was simplified

| Before | After | Why it is safe |
| ------ | ----- | -------------- |
| Table `auth_email_state` (lock, counter) (v1.12) | Removed; `auth_code.wrong_count` | PRD has no lock (Q-20) |
| Table `push_token` (v1.12) | Two columns of `device_session` | One token per device |
| Error `CODE_LOCKED` (v1.12) | Removed; a void code answers `CODE_EXPIRED` | One message "request a new code" |
| `auth_code.purpose`, `challenge_id` (v1.13) | Removed | One purpose is left, sign-in |
| Per-device revoke and device list (v1.13) | One endpoint `DELETE /v1/admin/sessions/others` | No device screen, no phone names; the need is "get rid of the lost phone" |
| Two window rules (strict list, loose detail) (v1.13) | One predicate `OrderWindow` | A single rule is easier to test and explain |
| Admin tables | 5 (unchanged since v1.12) | |

Kept on purpose: three route prefixes `/v1/auth`, `/v1/admin`, `/v1/owner` (one `RequireRole` per group); the 20 s refresh grace and rotation (owner accepted); `previous_refresh_hash` and `refresh_rotated_at`; `settings_change` and `order_event` (BR-3, invisible record); the `/impact` preview (FR-22); the admin ADRs (each is a separate, small decision).

## 25.3 Dropping deferred features: applied (v1.13)

The drop plan of v1.12 was applied to the system documents [v1.13 | 2026-10-31]. Nothing else depended on the dropped groups: ordinary sign-in, sessions, `wrong_count` and all orders are unchanged. The complete list is section 25.5. Restoring a feature later means reading the old text in git history and adding the group back; each group is closed (its own endpoints, columns and error codes).

## 25.4 Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version of this part (architecture.md v1.12). |
| 1.1 | 2026-10-31 | PRD v1.6: TQ-12 superseded, drop plan applied, list of deleted items (25.5), "sign out all other phones" added (architecture.md v1.13). |

## 25.5 Every item deleted or changed in v1.13 [v1.13 | 2026-10-31]

### Endpoints

| Deleted | Replaced by | Deferred item |
| ------- | ----------- | ------------- |
| `POST /v1/auth/recovery-requests` | none (operator, A-7) | P-1 |
| `POST /v1/auth/recovery-sessions` | none | P-1 |
| `PUT /v1/owner/backup-email` | none | P-1 |
| `POST /v1/owner/backup-email/confirmation` | none | P-1 |
| `GET /v1/admin/devices` | none | P-2 |
| `DELETE /v1/admin/devices/{device_id}` | `DELETE /v1/admin/sessions/others` (new, FR-4) | P-2 |
| `DELETE /v1/admin/push-token` | server clears the token at sign-out, sign out others, deactivation | D-7 |
| `GET /v1/admin/orders?view=unfinished` | the default list | P-3 |

List parameters deleted: repeated `status` (now one), `date_from`, `date_to` (now `delivery_date` or `date_preset`), `view`. Response fields deleted: `new_count`, `server_time` (D-5), `has_backup_email`, `offer_device_list`, `order_window_days`, detail `history` (D-4; replaced by `last_change`). Kept: `unfinished_count` (badge, FR-13).

### Tables, columns, constraints, events

| Deleted | Where |
| ------- | ----- |
| `account.backup_email`, `account.backup_email_confirmed_at`, trigger `account_email_guard` | data-model/04 3.10 |
| `auth_code.purpose` (values `recovery_owner`, `recovery_backup`, `backup_confirm`), `auth_code.challenge_id` | data-model/04 3.12 |
| `device_session.sign_in_method = recovery`; `revoked_reason = revoked_by_owner` (now `signed_out_others`) | data-model/04 3.11 |
| `security_event` types `sign_in_recovery`, `device_revoked`, `backup_email_changed`; column `actor_account_id` (type `sign_out_others` added) | data-model/04 3.15 |
| Cancel reason `day_full` (CHECK lists on `customer_order` and `order_event.reason`) | data-model/05 section 11 |
| Index description "Unfinished view and its count"; the New-count query | data-model/05 section 11 |

### Error codes and limits

`DEVICE_NOT_FOUND` deleted; `EMAIL_TAKEN` no longer mentions the backup address; `CODE_*` counters are per address only (no purpose); recovery request limits (20 an hour per client address, separate recovery counters) deleted; the recovery request is no longer counted as two mails.

### Decision text

| Document | Deleted or changed |
| -------- | ------------------ |
| ADR-0022 v1.3 | Recovery decision, backup e-mail, device list and per-device revoke, backup copy of the notice, separate recovery counters; added "Sign out all other phones" |
| ADR-0029 v1.3 | Unfinished view, `view=unfinished`, `new_count`, banner rule, date-range and multi-status filters, TQ-12 exception (detail-only window exception); one window predicate |
| ADR-0030 v1.1 | Five reasons to four (`day_full` removed) |
| ADR-0024 v1.3 | Notification-denied hint, `DELETE push-token`, settings screen explanation |
| ADR-0023 v1.2, ADR-0028 v1.2 | Recovery mails; window note rewritten |
| auth.md v2.3, session-lifecycle.md v1.3, auth/abuse-secrets-threats.md | Two-code recovery section, device list and revoke rows, recovery counters, backup-address notice |
| architecture/07, 08; admin-order-handling.md v1.1 | Recovery and device slices, hint row, five reasons, 90-day exception rows |
