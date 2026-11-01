# System Architecture: Slices B4 and B5 alignment, document corrections, open defects

Part of [architecture.md](../architecture.md) (index, version, change log), section 28. New in v1.16 [v1.16 | 2026-11-01]. Slices B4 (staff) and B5 (owner settings, districts, slots) are built; where the code was the better choice the system documents now follow it. Sources read: `backend/Sources/App/Routes/Admin/Owner*.swift`, `Services/Admin/Settings/*`, `Repositories/Admin/Settings*.swift`, `backend/db/migrations/0004_admin_settings.sql`, `contracts/fixtures/admin/owner-*.json` and `error-*` fixtures. Format as in [11-b2b3-alignment.md](11-b2b3-alignment.md).

## 28.1 Decisions and corrections

| Topic | Rule | Written in |
| ----- | ---- | ---------- |
| Staff list | `GET /v1/owner/staff` answers `{"accounts": [...]}`: owner first, then by name (case-insensitive), then creation time. Review accounts (`kind = 'review'`) are not listed, not counted toward the 30, and `PATCH` on one is 404 `NOT_FOUND`; their address still makes `EMAIL_TAKEN` | api/07 10.18, ADR-0027 v1.2 |
| Staff `PATCH` | Body `is_active` only; other keys are `FIELD_UNKNOWN`. Same state as stored is 200 and writes nothing (no `settings_change`, sessions untouched). Owner row: 409 `OWNER_PROTECTED`. Reactivation at 30 active: 409 `STAFF_LIMIT_REACHED`. Deactivation revokes every live session and clears the push token in the same transaction | api/07 10.18 |
| Staff e-mail | Stored trimmed, NFC, lower case (`EmailAddress`). Never logged, never in `settings_change` (an account row holds `is_active` only) and never in an error body | api/07 10.18, data-model/04 3.16 |
| Ordering `GET` | `GET /v1/owner/settings/ordering` returns `daily_limit`, `lead_days`, `min_qty`, `max_days_ahead` only. `over_limit` and `count` are on the `PUT` answer and on the `/impact` preview | api/07 10.15 |
| Empty and unknown input | `PATCH` with `{}`: 422 `VALIDATION_FAILED`, field `body`, code `BODY_EMPTY`. Unknown JSON key: field = key, code `FIELD_UNKNOWN`. Every field problem of one request is listed in `fields[]` (`FormReader`) | api/07 intro, api/08 |
| District name | Unique ignoring letter case; 422 `VALIDATION_FAILED`, field `name`, code `NAME_TAKEN`, `ERR_FIELD_TAKEN` (create and rename) | api/07 10.16, data-model/05 section 13 |
| Slot errors | `START_INVALID`, `END_INVALID` (not `HH:MM`), `END_OUT_OF_RANGE` (`end` not after `start`); a pair already used is its own 422 code `SLOT_DUPLICATE` (not in `fields[]`). A `PATCH` merges new and stored values before checking | api/07 10.16, api/08 |
| Sort order | After every slot add or move all slots get `sort_order` by clock time (start, then end), because the customer catalog sorts by `sort_order` first. A new district gets `max + 1`. The settings answer lists slots by start and end, districts by `sort_order` | api/07 10.13, 10.16, data-model/05 section 13 |
| Migration | `0004_admin_settings.sql` creates `settings_change` (append-only trigger; index on `shop_id, changed_at`) and the BR-11 CHECKs: `daily_limit <= 9999`, `lead_days <= 14`, `min_qty <= 20`, `min_qty <= daily_limit`, `delivery_fee_vnd <= 10000000`. The cake part (data-model/05 section 12) is still to come in B6 | data-model/05 section 15 |
| Concurrency | Every write locks the `shop_setting` row first (`SettingsWriter.lock`), so two owner devices, two staff additions at the limit and the "last active" checks are serialised; refusals throw before any write | api/07 intro |

## 28.2 Not built after B5

| Item | Decision | Reason |
| ---- | -------- | ------ |
| Cake add, hide, remove (`/v1/owner/cakes`) | Slice B6 | ADR-0025, ADR-0031 |
| Cake list filter | The cakes list in `GET /v1/owner/settings` has no `removed_at IS NULL` filter yet; B6 must add it with the removal | api/07 10.13 |
| Purge task, review-account sign-in | Unchanged from architecture/11 27.2 (review account built later: architecture/16 [v1.20 | 2026-11-01]); the push token route was built in B7 (architecture/14) [v1.18 | 2026-11-01] | go-live gate, slice A6 |

## 28.3 Other document and code differences found (B4 and B5)

| Item | Finding | Resolution |
| ---- | ------- | ---------- |
| `settings_change` migration | data-model/04 3.16 and data-model/05 section 15 placed it in `0002_admin_auth.sql`; `0002` has no such table | Fixed: it is in `0004` |
| Migration name | Documents said a later `_catalog` file for sections 12 and 13; section 13 is `0004_admin_settings.sql` | Fixed (data-model/05, ADR-0030 v1.3) |
| Message key | `NAME_TAKEN` on districts uses `ERR_FIELD_TAKEN`; the top-level `message_key` is `ERR_SERVER` as in the fixtures | Written in api/07 and api/08 |
| Dev guide | The B4/B5 paragraph matches the code; it is owned by forge-dev and was not edited | None |
| Fixtures | `owner-staff-list.json`, `error-slot-duplicate.json`, `error-settings-validation.json`, `error-owner-protected.json` agree with the code | None |

## 28.4 Open defects

None found that break the PRD (27 FR, 14 BR); the only open point is the cakes filter (28.2), which belongs to B6. Defects D-1 and D-2 of architecture/11 27.4 were not touched by B4 and B5; both are fixed in B6 (architecture/13) [v1.17 | 2026-11-01]. Query for the requirements agent: none. Query for forge-dev: D-1, D-2.
