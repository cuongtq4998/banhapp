# ADR-0029: Order list, filters, search, paging and the 90-day window

| Field    | Value |
| -------- | ----- |
| ADR      | 0029 |
| Version  | 1.8 [v1.8 | 2026-11-02] (cursor version marker, filters match the list date, window index still present; v1.7: (window text confirmed as `now - 90 x 24 hours`, ADR-0033 Decision 13; v1.6: unfinished definition and sort key moved to ADR-0033; v1.5: search minimum 3, opaque cursor and field codes as built; earlier: v1.3 simplified for PRD v1.6: one list, one window rule; Unfinished view, banner, `new_count`, multi-status and date-range filters removed) |
| Status   | Accepted (no money; the window follows the owner decision Q-13; retention remains an owner question). The TQ-12 exception of v1.2 (unfinished orders reachable for detail only) is superseded by v1.3: open orders are always in the window. Unfinished view, `view=unfinished`, banner and `new_count` are removed [v1.3 | 2026-10-31] | [v1.6 | 2026-11-02] Superseded in part by ADR-0033: the unfinished definition and the list sort key (list date = expected date when set, else requested date); the 90-day window and search stay.
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

Keyset paging, 50 rows a page (fixed). Sort key: `delivery_date`, `slot_start_time`, `created_at`, `id` ascending (BR-9). The cursor is the base64url of a version marker (`2`) and the four sort values of the last row, `(list_date, slot_start_time, created_at, id)`, with `list_date = COALESCE(expected_delivery_date, delivery_date)`; a cursor without the marker or with another version answers `CURSOR_INVALID`; the next page uses a row-value comparison `(list_date, slot_start_time, created_at, id) > (...)` [v1.8 | 2026-11-02]. The `delivery_date` and `date_preset` filters match `list_date` (owner decision Q-37). The window predicate reads `customer_order_shop_created_idx`, the open view `customer_order_open_list_idx` (data-model/06 section 9). Filters [v1.3 | 2026-10-31]: at most one `status` (`todo` = New and Confirmed, the default; `New`, `Confirmed`, `Completed`, `Cancelled`, `all`) and at most one delivery date (`date_preset` `today` or `tomorrow` by the shop date on the server, or `delivery_date`). Search `q`: 3 to 50 characters after trim (v1.5: was 2 in v1.1 to v1.4, corrected to the PRD BR-10 and the code); matches the order code (case-insensitive substring), the customer name (`unaccent(lower(name)) LIKE unaccent(lower('%' || escaped q || '%'))`, with `LIKE` wildcards in `q` escaped) and the phone (digits of `q` against the stored E.164 number, with a leading `0` read as `+84`). Extension `unaccent` is created by the migration (trusted since PostgreSQL 13; availability on the managed host is to be verified in CI and staging); if it is unavailable the fallback is plain `lower()` matching and a note to the UI that diacritics must match.

Consistency while paging (R-14) [v1.1 | 2026-10-31]: the four sort-key columns of an order never change after creation, so a row cannot move between pages and none repeats. An order placed after page 1 sorts into place and shows on a refresh from the first page (the badge and the push tell the user); a status change on a row not yet fetched can make it leave the filter, so it is simply not shown; a change on a row already shown is corrected by the next refresh. Nothing is guaranteed to be a snapshot; the list is read again on pull to refresh.

Partial search (TQ-D7) [v1.1 | 2026-10-31]: the server matches by substring on order code, name and phone digits, so a part of a name or of a phone number works. The minimum is 3 characters (3 digits for a phone), for the server and the apps alike [v1.5 | 2026-11-01]; v1.1 to v1.4 said 2 on the server and 3 in the apps, which contradicted BR-10. At about 9,000 rows in the window a scan takes a few milliseconds; the `pg_trgm` trigger above stays. Case and diacritics are ignored through `unaccent(lower())`; both sides are normalised to NFC first.

Replay note [v1.4 | 2026-11-01]: the window gates the list and the detail; the status route tests an exact repeat before the window (ADR-0028 v1.3, R-1).

Window [v1.3 | 2026-10-31] (supersedes the v1.2 window and the TQ-12 exception): one repository predicate in one function (`OrderWindow`): `status IN open (since ADR-0033: Received, Processing, DeliveryDateScheduled, DeliveryStarted) OR created_at >= now() - interval '90 days'`. Open orders of any age are always in the window; finished orders (Finished, Cancelled; Completed before ADR-0033) stay for 90 days after they were placed, rolling to the second (at exactly 90 days still shown, BR-9). The same function serves the list, the badge count, search, detail by code and status change, so an old open order is found by the default list and by search, can be opened and can be closed, and once it is finished it leaves the window after its 90 days (an order placed more than 90 days ago and finished today is out of the window from then on; the status-change reply still returns it once, read inside the same transaction). Outside the window the order answers 404 `ORDER_NOT_FOUND`, the same as a code that does not exist. The push tap uses the detail path, so it is covered. The window is a display rule, not retention: rows stay (data-model section 6); the retention period and purge job wait for the owner (Place Order Q-O4, DM-Q1).

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

## Amendment v1.5 [v1.5 | 2026-11-01]: as built in slices B2 and B3

- Minimum length of `q` is 3 (see above). A text of only digits, spaces and `+-().` is also matched as a phone number and needs 3 digits. Control characters (PostgreSQL text cannot hold NUL) are rejected with `SEARCH_INVALID`; the text is NFC-normalised and trimmed first.
- The fold is the SQL function `search_fold(text)`, created by migration 0003: `lower(unaccent(x))` when the host lets the migration create `unaccent`, plain `lower(x)` otherwise. The application never branches on it. Where `unaccent` is used the function is `STABLE`, not `IMMUTABLE`, so it cannot back an index; this matches the scan decision above.
- The cursor is an opaque string to clients: the encoding is internal and may change without a version change (a cursor issued by an older release then answers `CURSOR_INVALID`). A cursor that the server cannot read answers 422 `VALIDATION_FAILED` with field code `CURSOR_INVALID`. The list of field codes is in api/08 section 11.1.
- Unknown and repeated parameters, and a preset together with a date, are 422 field errors (`UNKNOWN_PARAMETER`, `REPEATED_PARAMETER`, `DATE_FILTER_CONFLICT`); the 50-row page size is fixed.
