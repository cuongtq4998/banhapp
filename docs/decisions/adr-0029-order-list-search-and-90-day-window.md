# ADR-0029: Order list, filters, search, paging and the 90-day window

| Field    | Value |
| -------- | ----- |
| ADR      | 0029 |
| Version  | 1.0 |
| Status   | Accepted (no money; the window follows the owner decision Q-13; retention remains an owner question) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD FR-8 to FR-13, FR-41, BR-13, BR-20, AC-15 to AC-23, AC-67, AC-68; TQ-5, TQ-7; data-model 3.7 |

## Context

At most about 100 orders a day, so about 9,000 orders fall in 90 days. Rows must not repeat across pages while new orders arrive (AC-23). Staff type names on phones, often without Vietnamese diacritics. The window must apply to every read path, including a push tap.

## Decision Drivers

- Correct under inserts; simple SQL; no extra service.
- One place enforces the window.
- Index use should be real but need not be tuned for this size.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| Paging A. Offset | Simple | Duplicates and gaps while orders arrive |
| Paging B. Keyset cursor on the sort key (chosen) | Stable, index friendly | Opaque cursor to build |
| Search A. `ILIKE` with `unaccent` on a sequential or index-assisted scan (chosen) | Matches "Thi B" to "Thị B"; no new column; fast at 9,000 rows | Not index-assisted for infix; extension needed |
| Search B. `pg_trgm` index | Index for infix | Overkill now |
| Search C. A stored unaccented name column | Plain index | Extra copy of personal data |

## Decision

Keyset paging, 50 rows a page (fixed). Sort key: `delivery_date`, `slot_start_time`, `created_at`, `id` ascending (BR-13). The cursor is the base64url of those four values of the last row; the next page uses a row-value comparison `(delivery_date, slot_start_time, created_at, id) > (...)`. Filters: status set (default New and Confirmed; `all`), delivery date presets `today`, `tomorrow` (shop date on the server) or `date_from`/`date_to` (range, one date is a range of one day). Search `q`: 2 to 50 characters after trim; matches the order code (case-insensitive substring), the customer name (`unaccent(lower(name)) LIKE unaccent(lower('%' || escaped q || '%'))`, with `LIKE` wildcards in `q` escaped) and the phone (digits of `q` against the stored E.164 number, with a leading `0` read as `+84`). Extension `unaccent` is created by the migration (trusted since PostgreSQL 13; availability on the managed host is to be verified in CI and staging); if it is unavailable the fallback is plain `lower()` matching and a note to the UI that diacritics must match. `new_count` is a separate count query of status New inside the window (served by the index `(shop_id, status, created_at)`).

Window: one repository predicate `created_at >= now() - interval '90 days'` (rolling to the second, so AC-68 holds), built in a single function (`OrderWindow`) and used by the list, the count, search, detail by code and status change. An order outside the window answers 404 `ORDER_NOT_FOUND`, the same as a code that does not exist. The push tap uses the detail path, so it is covered. The window is a display rule, not retention: rows stay (data-model section 6); the retention period and purge job wait for the owner (Place Order Q-O4, DM-Q1).

Indexes: the existing `(shop_id, delivery_date, status)` and `(shop_id, status, created_at)` serve the list and the count; add `customer_order (shop_id, created_at)` for the window scan (data-model/05). Targets: list first page p95 at most 500 ms on a warm database.

## Consequences

- Positive: stable pages, one window function, no extra PII copy.
- Negative: search scans the window (about 9,000 rows, a few milliseconds); the free database may wake first.
- Follow-up: trigram index if volume grows 20 times; owner states the retention period.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Keyset (seek) pagination avoids offset duplicates | https://use-the-index-luke.com/no-offset | from memory, not fetched | Medium |
| `unaccent` is a trusted extension since PostgreSQL 13; the rules map `đ` to `d` | https://www.postgresql.org/docs/current/unaccent.html | from memory, not fetched | Medium to low |

## Links

Related: ADR-0028. Detail: api/06, data-model/05.
