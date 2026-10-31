# ADR-0029: Order list, filters, search, paging and the 90-day window

| Field    | Value |
| -------- | ----- |
| ADR      | 0029 |
| Version  | 1.3 [v1.3 | 2026-10-31] (simplified for PRD v1.6: one list, one window rule; Unfinished view, banner, `new_count`, multi-status and date-range filters removed) |
| Status   | Accepted (no money; the window follows the owner decision Q-13; retention remains an owner question). The TQ-12 exception of v1.2 (unfinished orders reachable for detail only) is superseded by v1.3: open orders are always in the window. Unfinished view, `view=unfinished`, banner and `new_count` are removed [v1.3 | 2026-10-31] |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD admin-orders v1.6 FR-9 to FR-14, FR-19, FR-13, BR-9, BR-10, AC-13 to AC-22; TQ-5, TQ-7, TQ-12 (superseded); data-model 3.7 (ids as in product/admin-orders/08, section 15) [v1.3 | 2026-10-31] |

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

Keyset paging, 50 rows a page (fixed). Sort key: `delivery_date`, `slot_start_time`, `created_at`, `id` ascending (BR-9). The cursor is the base64url of those four values of the last row; the next page uses a row-value comparison `(delivery_date, slot_start_time, created_at, id) > (...)`. Filters [v1.3 | 2026-10-31]: at most one `status` (`todo` = New and Confirmed, the default; `New`, `Confirmed`, `Completed`, `Cancelled`, `all`) and at most one delivery date (`date_preset` `today` or `tomorrow` by the shop date on the server, or `delivery_date`). Search `q`: 2 to 50 characters after trim; matches the order code (case-insensitive substring), the customer name (`unaccent(lower(name)) LIKE unaccent(lower('%' || escaped q || '%'))`, with `LIKE` wildcards in `q` escaped) and the phone (digits of `q` against the stored E.164 number, with a leading `0` read as `+84`). Extension `unaccent` is created by the migration (trusted since PostgreSQL 13; availability on the managed host is to be verified in CI and staging); if it is unavailable the fallback is plain `lower()` matching and a note to the UI that diacritics must match.

Consistency while paging (R-14) [v1.1 | 2026-10-31]: the four sort-key columns of an order never change after creation, so a row cannot move between pages and none repeats. An order placed after page 1 sorts into place and shows on a refresh from the first page (the badge and the push tell the user); a status change on a row not yet fetched can make it leave the filter, so it is simply not shown; a change on a row already shown is corrected by the next refresh. Nothing is guaranteed to be a snapshot; the list is read again on pull to refresh.

Partial search (TQ-D7) [v1.1 | 2026-10-31]: the server accepts `q` from 2 characters and matches by substring on order code, name and phone digits, so a part of a name or of a phone number works; the apps may require 3 characters before calling, that is a UI choice. At about 9,000 rows in the window a scan takes a few milliseconds; the `pg_trgm` trigger above stays. Case and diacritics are ignored through `unaccent(lower())`; both sides are normalised to NFC first.

Window [v1.3 | 2026-10-31] (supersedes the v1.2 window and the TQ-12 exception): one repository predicate in one function (`OrderWindow`): `status IN ('New','Confirmed') OR created_at >= now() - interval '90 days'`. Open orders of any age are always in the window; finished orders (Completed, Cancelled) stay for 90 days after they were placed, rolling to the second (at exactly 90 days still shown, BR-9). The same function serves the list, the badge count, search, detail by code and status change, so an old open order is found by the default list and by search, can be opened and can be closed, and once it is finished it leaves the window after its 90 days (an order placed more than 90 days ago and finished today is out of the window from then on; the status-change reply still returns it once, read inside the same transaction). Outside the window the order answers 404 `ORDER_NOT_FOUND`, the same as a code that does not exist. The push tap uses the detail path, so it is covered. The window is a display rule, not retention: rows stay (data-model section 6); the retention period and purge job wait for the owner (Place Order Q-O4, DM-Q1).

Badge count (FR-13) [v1.3 | 2026-10-31]: every list response carries `unfinished_count`, the number of orders with `status IN ('New','Confirmed') AND delivery_date <= shop_today AND is_demo = :account_is_review`, whatever the filters. `shop_today` is the shop calendar day (A-1) already used for `server_date`. The app refetches page 1 after every status change, which refreshes the badge. There is no `view` parameter, no separate Unfinished list, no banner and no `new_count`: the default list already holds every open order, earliest delivery first, so the overdue ones are on top. A partial index `customer_order (shop_id, delivery_date) WHERE status IN ('New','Confirmed')` holds only open orders (a few dozen rows). The labels "due today" and "overdue N days" are computed by the app from `delivery_date` and `server_date`; rows carry no phone or address (BR-7).



Indexes: the existing `(shop_id, delivery_date, status)` serves the list; add `customer_order (shop_id, created_at)` for the window scan and the partial index above (data-model/05). Tests cover an old open order (listed, searched, opened, closed), a finished order at exactly 90 days and at 90 days plus one second, and the demo split (AC-13, AC-18, AC-22). Targets: list first page p95 at most 500 ms on a warm database.

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
