# Place Order: Test Plan and Report

| Field        | Value |
| ------------ | ----- |
| Version      | 1.1 |
| Last updated | 2026-10-26 |
| Status       | Draft |
| Owner        | probe-qa |
| Based on     | product/place-order.md v1.2 (Approved); design/place-order-ui.md v1.0; system/api.md v1.0, order-lifecycle.md v1.0, auth.md v1.0, data-model.md v1.0, architecture.md v1.0; ADR-0005, 0008 to 0011, 0013 to 0015 |
| Related      | process/standards/11-test.md; engineering/dev-guide.md (not yet written); backend/Tests/qa/ (executable tests) |

## 1. Scope & Environment

[v1.1 | 2026-10-26] Round 1 (execute mode, slice 0 only) ran on commit f940495 (feature/place-order). Slice 0 = `/healthz`, migration `0001_init.sql`, sample seed, config validation, repository layout, CI workflows, empty iOS and Android shells (architecture.md section 11). Host: macOS arm64, Swift 6.2.4, no PostgreSQL, no Docker, no psql, so database-level tests are written and compile but are **unrun here** (they skip unless `DATABASE_MIGRATION_URL` points at a throwaway PostgreSQL 14+). A backend fix round by forge-dev is in flight; results below apply to f940495 only. The remainder of this section is the v1.0 early-mode text.

Mode: EARLY (plan only) in v1.0; v1.1 adds execute mode for slice 0 (see above). The code does not exist. Every result is `Not run`. This version is a test plan plus a review of the document set. No build, test or git command was run.

In scope: the Customer app on iOS and Android (S-1 to S-9) and the backend (Swift Vapor, PostgreSQL; owner decision, final) from launch to the confirmation screen. Out of scope: staff and owner features, payment, tracking, cancellation endpoints (BR-9 is tested at database level only, see TC-59).

Levels:

| Level | Prefix | Tooling (proposed; forge-dev to confirm in the dev guide) |
| ----- | ------ | --------------------------------------------------------- |
| API / backend (including database) | TC-1 to TC-70 | HTTP-level tests against a real PostgreSQL, parallel requests for races, SQL access for assertions |
| iOS UI | TC-101 to TC-165 | XCTest / XCUITest against a stub or test backend, simulator iOS 17.x and 26.x; real device for Zalo and dialer |
| Android UI | TC-201 to TC-267 | Compose UI tests and instrumented tests, emulator API 26 and API 31+ (or newer); real device for Zalo and dialer |

Environment needs are in section 3. Commands: `CLAUDE.md` still describes the template Xcode project (iOS 15, multiplatform, no backend); the real commands are unknown until the dev guide exists (see Q-P1).

Conventions in the cases: today `D` = 2026-11-02 (Monday, shop time) from the controlled clock. Fake seed (section 3): DAILY_LIMIT 10, LEAD_DAYS 2, MIN_QTY 2, MAX_DAYS_AHEAD 30; cakes A 50000, B 60000, C 70000, E 40000 VND; districts Q1 fee 20000, Q2 fee 30000, Q3 inactive; slots S1 08:00-10:00, S2 10:00-12:00, S3 14:00-16:00. Date fixtures: 2026-11-10 has 8 cakes accepted (remaining 2), 2026-11-11 has 10 (full), 2026-11-12 has 9 (remaining 1), 2026-11-13 empty (remaining 10). "Order X" means a valid body for the stated items and date unless a field is named.

Types: acceptance, negative, edge, regression, extra. Result values: Not run, Pass, Fail, Blocked.

## 2. Traceability Matrix

| AC | Requirement | Cases (API) | Cases (iOS) | Cases (Android) |
| -- | ----------- | ----------- | ----------- | --------------- |
| AC-1 | FR-1 | | TC-101 | TC-201 |
| AC-2 | FR-2 | TC-1, TC-69 | TC-102, TC-132 | TC-202, TC-232 |
| AC-3 | FR-2 | TC-69 | TC-103, TC-104, TC-105 | TC-203, TC-204, TC-205 |
| AC-4 | FR-3 | TC-1 | TC-106, TC-107, TC-133 | TC-206, TC-207, TC-233 |
| AC-5 | FR-4 | | TC-108, TC-134 | TC-208, TC-234 |
| AC-6 | FR-5 | TC-16 | TC-109 | TC-209 |
| AC-7 | FR-6, BR-2 | TC-4, TC-5, TC-23, TC-24, TC-62 | TC-110 | TC-210 |
| AC-8 | FR-6, BR-1 | TC-7 | TC-111 | TC-211 |
| AC-9 | FR-10, BR-1 | TC-17 | TC-113 | TC-213 |
| AC-10 | FR-7, BR-11 | TC-1, TC-8 | TC-114 | TC-214 |
| AC-11 | FR-8, BR-3 | TC-1, TC-26 | TC-115 | TC-215 |
| AC-12 | FR-13 | TC-27, TC-28, TC-29 | TC-116 | TC-216 |
| AC-13 | FR-10, BR-4 | TC-22 | TC-117 | TC-217 |
| AC-14 | FR-9, BR-5 | TC-15 | TC-118 | TC-218 |
| AC-15 | FR-11, BR-7 | TC-12, TC-13 | TC-119 | TC-219 |
| AC-16 | FR-11 | TC-14, TC-64 | TC-120 | TC-220 |
| AC-17 | FR-12 | | TC-121 | TC-221 |
| AC-18 | FR-15 | | TC-122 | TC-222 |
| AC-19 | FR-16 | TC-36, TC-37 | TC-123, TC-144 | TC-223, TC-244 |
| AC-20 | FR-17 | TC-54 | TC-124 | TC-224 |
| AC-21 | FR-14 | TC-56 | TC-125 | TC-225 |
| AC-22 | BR-1 | TC-18, TC-19 | TC-126 | TC-226 |
| AC-23 | BR-6 | TC-43, TC-45 | TC-127 | TC-227 |
| AC-24 | FR-6, BR-8 | TC-6, TC-25 | TC-112 | TC-212 |
| AC-25 | FR-11 | TC-13 | TC-128 | TC-228 |
| AC-26 | FR-18 | TC-32 | TC-129 | TC-229 |
| AC-27 | FR-19 | TC-2, TC-13 | TC-130 | TC-230 |
| AC-28 | BR-1, BR-9 | TC-59 (database level only) | not applicable (no UI) | not applicable (no UI) |
| AC-29 | FR-2, FR-3 | TC-2, TC-66 | TC-131 | TC-231 |

All 29 ACs have at least one case. AC-23 and AC-28 can only be proven at database level in this slice (no screen or endpoint shows a stored order); see Q-S4 and Q-S5.

## 3. Test data and environment needs (what forge-dev must provide)

| # | Need | Detail | Used by |
| - | ---- | ------ | ------- |
| E-1 | Controllable clock | Backend: an injectable clock (config or test-only endpoint/env, never in production) to set "now" to an instant such as 2026-11-02T00:00:00+07:00, 23:59:59+07:00, and 2026-11-02T17:30:00Z (= 00:30 on 11-03 shop time), and to move it during a test (midnight crossing, 24 h window). Apps: an injectable clock/date provider so the UI tests run with `server_date` fixed. | TC-4 to TC-6, TC-23 to TC-25, TC-49, TC-62, TC-110, TC-112, TC-142, TC-146 |
| E-2 | Seed data | A test seed (separate from `sample.sql`, or the same with the values above) with `is_sample = true`: four cakes, three districts (one inactive), three slots, DAILY_LIMIT 10, settings per section 1, `day_load` rows for the date fixtures. A reset script to restore the seed before each test class. | all |
| E-3 | Database access in tests | Direct SQL for assertions (orders, items, `day_load`, `order_event`), for price/fee/district/product changes between calls (TC-43, TC-44, TC-46), for the reconciliation query (TC-61), and for status changes (TC-59, TC-60). | API |
| E-4 | Test mode flags | `ORDERING_ENABLED`, rate-limit values (`RATE_LIMIT_*`, `ORDER_MAX_PER_PHONE_PER_DAY`) and `TRUST_PROXY` settable per test run; a way to reset the in-memory limiter between tests; a hook to force order-code collisions (fixed random source) for TC-64; a hook to make the database unreachable (TC-54). | TC-48 to TC-54, TC-64 |
| E-5 | Stub or fault-injecting backend for UI tests | A local stub server (or protocol/interface fake in the apps) that can return, on demand: each error code in api.md section 5, delays over 10 s, no connection, 304, availability that changes between calls, `PRICE_CHANGED` with details. Contract fixtures `contracts/fixtures/` shared by the three suites (architecture.md). | TC-105, TC-113, TC-123 to TC-127, TC-138, TC-155 to TC-157 and Android mirrors |
| E-6 | Test accessibility ids | Stable accessibility identifiers / test tags for every control, field, error message and state in UI sections 5.1 to 5.9, and the localisation keys exposed so tests can assert text by key. | UI |
| E-7 | Fake assets | Four placeholder images, logo, one broken image URL. No real data. | UI, TC-67 |
| E-8 | Devices | iOS simulator 17.x and 26.x; real iPhone with and without the Zalo app and with a SIM-less dialer check. Android emulators API 26, API 30, API 31+ (latest); real Android phone with and without Zalo. Simulators cannot place calls; Zalo behaviour is unverified (ADR-0015), so TC-103/203 and TC-104/204 are `Blocked` until a device is available. | TC-103, TC-104, TC-121 |
| E-9 | Concurrency harness | A test client that sends N requests at the same instant (barrier) against a real PostgreSQL service container (as in deployment.md section 5 step 1). | TC-18, TC-19, TC-37 |
| E-10 | Log capture | Access to backend log output of a test run to check no personal data is logged (TC-65). | TC-65 |
| E-11 | Commands | A dev guide with the exact build, unit, integration and UI test commands for the Vapor backend, iOS and Android; `CLAUDE.md` updated (it still shows iOS 15 / multiplatform). | all |
| E-12 | Fake personal data | Names such as "Nguyen Van A" / "Nguyễn Văn A", phones `0900000000` to `0900000099` (fake range), address "1 Duong Mau". No real data anywhere. | all |

## 4. Test Cases

### 4.1 API / backend level

| ID | Type | Covers | Preconditions | Steps | Expected | Result |
| -- | ---- | ------ | ------------- | ----- | -------- | ------ |
| TC-1 | acceptance | AC-2, AC-4, AC-10, AC-11 | Seed loaded | `GET /v1/catalog` | 200. `shop` has name, greeting, `phone_contact`, `zalo_contact`. Exactly 4 products with picture path, name, description, price. Districts list only active ones (Q1, Q2, not Q3) with fees. Slots list is one list (3), no per-date data. `settings` has min_qty 2, lead_days 2, max_days_ahead 30, note_max_length 200. `server_date` is today in shop time | Not run |
| TC-2 | acceptance | AC-27, AC-29 | Seed loaded | `GET /v1/catalog`; search the body and all other responses for `is_sample`, `daily_limit`, "sample", "demo", "test", "thanh toan", "payment", "chuyen khoan" | None found. No payment field in any response | Not run |
| TC-3 | extra | FR-3 | Seed loaded. Reason: ADR-0011 relies on ETag | `GET /v1/catalog`, then again with `If-None-Match` of the first ETag; change a price in the database; again with the old ETag | Second call 304 with empty body. Third call 200 with new ETag and new price | Not run |
| TC-4 | acceptance | AC-7 | Clock D 12:00 | `GET /v1/availability?cakes=2` | `dates` starts at D. D and D+1 `available=false, reason=TOO_SOON`. D+2 (2026-11-04) `available=true` (if capacity) | Not run |
| TC-5 | edge (extra) | AC-7, BR-2 | Reason: AC-7 says "whatever the time of day". Clock at D 00:00:00 and at D 23:59:59 (+07:00) | Call availability at each time | Identical `dates` and availability at both times; D+2 earliest | Not run |
| TC-6 | acceptance | AC-24 | Clock D | `GET /v1/availability?cakes=2` | 31 entries, D to D+30 (2026-12-02) inclusive. D+30 `available=true` (no load). No entry for D+31 | Not run |
| TC-7 | acceptance | AC-8 | Fixtures: 11-10 remaining 2, 11-11 full, 11-12 remaining 1 | `cakes=2`, then `cakes=3`, then `cakes=1` | cakes=2: 11-10 available, 11-12 `FULL`, 11-11 `FULL`. cakes=3: 11-10 `FULL`. cakes=1: 11-12 available. Remaining amounts never present in the body | Not run |
| TC-8 | acceptance | AC-10, BR-11 | Seed | Order A for 11-13 with slot S1, then one with S3, then availability for the same cakes | Both orders accepted with any slot; availability of 11-13 depends only on cakes accepted, not on the slot used; no slot parameter changes the result (request with `slot_id` query is ignored or rejected consistently, see Q-A3) | Not run |
| TC-9 | negative (extra) | api 4.2 | Reason: input bounds | `GET /v1/availability` with cakes missing, 0, -1, 397, 396, 1, "abc", "2.5", "" | Missing/0/-1/397/abc/2.5/empty: 422 `VALIDATION_FAILED`. 1 and 396: 200 | Not run |
| TC-10 | edge (extra) | api 4.2 | Reason: reason precedence unspecified (Q-A4). 11-11 is full; clock D | Fixture where a date is both too soon and full (set load on D+1 to 10) | Reason for D+1 is `TOO_SOON` or `FULL` consistently; record the actual and compare with the answer to Q-A4. Date is `available=false` either way | Not run |
| TC-11 | edge (extra) | BR-1 | Reason: order larger than DAILY_LIMIT | `availability?cakes=11` (limit 10); then `POST /v1/orders` with 11 cakes for 11-13 | All dates `FULL` (UI Empty state of S-6). POST returns 409 `DATE_CAPACITY`, nothing stored | Not run |
| TC-12 | acceptance | AC-15, BR-7 | Seed, clock D, 11-13 empty | `POST /v1/orders` with new key: items A x2, date 11-13, slot S1, name "Nguyễn Văn A", phone "0900 000 000", address "1 Đường Mẫu", district Q1, note "Giao buổi sáng", `expected_total_vnd` 120000 | 201 `{order_code, created_at}`. Database: one order (status New) with name, phone `+84900000000`, address, district Q1, note, slot, date; one item with price snapshot 50000; fee snapshot 20000; total 120000; `day_load` 11-13 = 2; one `created` event | Not run |
| TC-13 | acceptance | AC-15, AC-25, AC-27 | As TC-12 | Inspect the 201 body and headers | Body has only `order_code` and `created_at`. No status, no payment field, no total, no prices, no personal data. Header `X-Request-Id` present | Not run |
| TC-14 | acceptance | AC-16 | Seed | Create 200 orders (different dates and phones to stay under limits, limits raised for the test). Check each code | All codes match `^BT-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$` and are unique; database unique index exists | Not run |
| TC-15 | acceptance | AC-14, BR-5 | Seed | Order A x2 + B x1, district Q1, `expected_total_vnd` 180000 | 201. Stored total 180000 = 2x50000 + 60000 + 20000, whole dong. With `expected_total_vnd` 179999: 409 `PRICE_CHANGED` with `total_vnd` 180000 | Not run |
| TC-16 | acceptance | AC-6 | Seed | Order with items C x2 and E x3 only (the UI sends no zero lines); then an order with a line quantity 0 | First: 201 with 2 item rows, total cakes 5. Second: 422 `VALIDATION_FAILED` (quantity below 1) | Not run |
| TC-17 | acceptance | AC-9 | 11-12 remaining 1... use 11-10 remaining 2 | Availability (cakes=2) shows 11-10 available. Then insert 1 cake directly into `day_load` for 11-10 (remaining 1). POST order of 2 cakes for 11-10 | 409 `DATE_CAPACITY` with `details.delivery_date` 2026-11-10; no order row, no event, `day_load` unchanged | Not run |
| TC-18 | acceptance | AC-22 | 11-10 remaining 2; two prepared valid orders (different phones, keys), each 2 cakes | Send both at the same instant (barrier) | Exactly one 201 and one 409 `DATE_CAPACITY`. `day_load` 11-10 = 10. One order row. Repeat 20 times; every run has exactly one winner | Not run |
| TC-19 | edge (extra) | G-2, AC-22 | Reason: architecture.md target "0 orders beyond the limit under 50 parallel requests". 11-13 empty, limit 10 | 50 parallel orders of 1 to 3 cakes (random but fixed seed), different keys and phones (limits raised) | Sum of cakes accepted is at most 10; `day_load` equals the sum of accepted orders (TC-61); every response is 201 or 409; no 500; all answers within 10 s | Not run |
| TC-20 | edge (extra) | BR-1 | Reason: exact fit. 11-10 remaining 2 | Order of 2 cakes for 11-10. Then availability cakes=2 and cakes=1 | 201. `day_load` = 10. 11-10 is now `FULL` for cakes=1 and 2 | Not run |
| TC-21 | edge (extra) | BR-1 | Reason: one over. 11-10 remaining 2 | Order of 3 cakes | 409 `DATE_CAPACITY`; `day_load` stays 8 | Not run |
| TC-22 | negative | AC-13 | Seed | Order with total 1 cake (A x1); then A x2; then A x1 + B x1; then 396 total is not needed | 1 cake: 422 `MIN_QTY`, `details.min_qty` 2, nothing stored. A x2: 201. A x1 + B x1: 201 (total across lines counts) | Not run |
| TC-23 | edge | AC-7, BR-2 | Clock D 09:00 | Order for D, D+1, D+2, with D+2 = 2026-11-04 | D and D+1: 422 `DATE_LEAD` (`details.lead_days` 2). D+2: 201. A past date (2026-10-01): 422 `DATE_LEAD` | Not run |
| TC-24 | edge (extra) | BR-2, A-8 | Reason: midnight crossing. Clock D 23:59:00; availability read earlier showed D+2 available | Move clock to D+1 00:01:00; POST order for D+2 | 422 `DATE_LEAD` (order date is the day of confirmation). At D+1 00:01 the order for D+3 is accepted | Not run |
| TC-25 | edge | AC-24, BR-8 | Clock D | Order for D+30 (2026-12-02), then D+31 (2026-12-03) | D+30: 201 (capacity permitting). D+31: 422 `DATE_HORIZON` (`details.max_days_ahead` 30). Far date 2030-01-01 also `DATE_HORIZON` | Not run |
| TC-26 | negative | AC-11, BR-3 | Q3 inactive | Order with district Q3; with a random unknown uuid; with district omitted | Q3: 422 `DISTRICT_UNSERVED`. Unknown uuid: `DISTRICT_UNSERVED` or `VALIDATION_FAILED` (spec says "not served or inactive"; record actual, see Q-A5). Omitted: 422 `VALIDATION_FAILED` with field `customer.district_id`. Delivery fee equals the fee of the chosen district (Q2: total uses 30000); never 0 | Not run |
| TC-27 | negative | AC-12 | Seed | Separate orders with: name empty, name only spaces, phone empty, address empty, address only spaces, district missing; all at once | Each: 422 `VALIDATION_FAILED`, `fields[]` names the field with code and `message_key` (`ERR_NAME_REQUIRED`, `ERR_PHONE_REQUIRED`, `ERR_ADDRESS_REQUIRED`, `ERR_DISTRICT_REQUIRED`). All at once: all five listed. Nothing stored | Not run |
| TC-28 | edge | AC-12, ADR-0009 | Seed | Valid phone writings, each in an order: `0900000000`, `090 000 0000`, `090.000.0000`, `090-000-0000`, `(090) 000-0000`, `+84900000000`, `+84 900 000 000`, `84900000000`, `0300000000`, `0500000000`, `0700000000`, `0800000000` | All 201, stored as `+84900000000` (or the matching E.164). Rate/limit counters treat the writings as one phone | Not run |
| TC-29 | negative | AC-12, ADR-0009 | Seed | Invalid phones: `0100000000`, `0200000000`, `0400000000`, `0600000000`, `028 1234 5678` (landline), `090000000` (9 digits), `09000000000` (11 digits), `abcdefghij`, `+1 555 000 0000`, `+84 0900000000`, `840900000000`, `84900000` , emoji, `0900000000x` | All 422 `VALIDATION_FAILED`, field `customer.phone`, `ERR_PHONE_INVALID`. Nothing stored | Not run |
| TC-30 | edge (extra) | ADR-0009 | Reason: length boundaries | Name 1, 100, 101 code points; address 1, 250, 251; name/address with leading/trailing spaces (trimmed) | 1 and 100 / 250: 201. 101 / 251: 422 `VALIDATION_FAILED`. Stored value is trimmed. Server text field errors other than the listed keys map to `ERR_SERVER` (UI) | Not run |
| TC-31 | edge (extra) | ADR-0009 | Reason: Vietnamese diacritics may be sent composed or decomposed | Name of 100 code points in NFC; same name in NFD (more code points); address with mixed forms | NFC form accepted. NFD form is normalised to NFC before counting (so 100 NFC-equivalent characters in NFD is accepted); stored value is NFC; two orders differing only in form store identical text | Not run |
| TC-32 | edge | AC-26 | Seed | Note of 0 (null), omitted, "", 1, 200, 201 code points (200 Vietnamese characters with diacritics in NFD form) | null/omitted/""/1/200: 201, note stored (null or empty for none). 201: 422 `VALIDATION_FAILED`, field `note`, `ERR_NOTE_MAX`. 200 NFD diacritic characters accepted (counted after NFC) | Not run |
| TC-33 | negative (extra) | security | Reason: injection and control characters | Name `'); DROP TABLE customer_order;--`, address `<script>alert(1)</script>`, note with newline (allowed), name with newline or NUL or tab (rejected), emoji, right-to-left text | SQL-like and HTML text stored literally and returned nowhere; tables intact. Control characters other than newline in address/note: 422. Emoji handled without 500 | Not run |
| TC-34 | negative (extra) | api 4.3 | Reason: item structure | `items` empty; 5 entries; duplicate `product_id`; quantity 99; 100; -1; 1.5; "2" (string); null; unknown `product_id` format ("abc"); extra unknown top-level field | Empty, 5, duplicate, 100, -1, 1.5, string, null, bad uuid, unknown field: 422 `VALIDATION_FAILED`. 99 of one cake: accepted only if capacity allows (else `DATE_CAPACITY`) | Not run |
| TC-35 | negative (extra) | api 4.3 | Reason: date format | `delivery_date` "2026-13-45", "02/11/2026", "2026-11-4", 20261104, null, "2026-02-30" | 422 `VALIDATION_FAILED` for each; no 500 | Not run |
| TC-36 | acceptance | AC-19 | 11-13 empty | POST order with key K. Repeat the identical request with K | First 201 code X. Second 200 with header `Idempotent-Replay: true` and body code X. One order row, `day_load` increased once, one `created` event | Not run |
| TC-37 | acceptance | AC-19 | 11-13 empty | 20 simultaneous identical requests with key K (barrier) | All responses carry the same `order_code`; one 201, the rest 200 replay (or 201 only once); exactly one order row; `day_load` increased once; no 500 | Not run |
| TC-38 | negative (extra) | api 4.3 | Reason: key misuse | POST with key K (201). POST with K and a different body (quantity changed) | 422 `IDEMPOTENCY_KEY_REUSED`; no second order | Not run |
| TC-39 | edge (extra) | ADR-0008 | Reason: "a rejected attempt is processed again". 11-10 remaining 1 | POST 2 cakes for 11-10 with key K (409). Free capacity in the database (remaining 2). POST the same request with K | First 409, no state. Second 201 | Not run |
| TC-40 | negative (extra) | api 1 | Reason: required headers | POST without `Idempotency-Key`; with "not-a-uuid"; with a UUID v1; without `X-Platform`; with `X-Platform: windows`; without `X-App-Version`; with `X-App-Version: abc` | 400 `IDEMPOTENCY_KEY_REQUIRED` or `HEADER_INVALID` as in the spec; nothing stored. UUID version and bad semver behaviour recorded (see Q-A6) | Not run |
| TC-41 | edge (extra) | ADR-0008 | Reason: "same normalised body" | POST with key K, phone "0900 000 000". Repeat with K, phone "+84900000000", same other fields | 200 replay (same normalised body). With a different note: 422 `IDEMPOTENCY_KEY_REUSED`. Record whether `expected_total_vnd` is part of the hash (Q-A7) | Not run |
| TC-42 | edge (extra) | auth 4 | Reason: "a replay is not counted again" | Per-phone limit 5; place 4 orders for phone P; replay one of them 10 times; place the fifth | Replays do not consume the per-IP or per-phone budget; fifth order accepted | Not run |
| TC-43 | acceptance | AC-23, BR-6, ADR-0010 | Price of A 50000; order body shows `expected_total_vnd` 120000 (A x2 + fee 20000) | Change A to 55000 in the database. POST the order | 409 `PRICE_CHANGED`; `details.items` contains A 55000; `delivery_fee_vnd` 20000; `total_vnd` 130000; no order, no `day_load` change. Then POST again with `expected_total_vnd` 130000 (same key): 201 with stored price 55000 | Not run |
| TC-44 | edge (extra) | ADR-0010 | Reason: fee change | Change fee of Q1 to 25000 between review and POST | 409 `PRICE_CHANGED` with `delivery_fee_vnd` 25000 and new total | Not run |
| TC-45 | acceptance | AC-23 | Order TC-12 stored | Change price of A to 99000 and fee of Q1 to 99000 in the database. Read the order and item rows; try to update the price columns of the order directly | Stored snapshot (50000, fee 20000, total 120000) unchanged. Direct UPDATE of snapshot columns is rejected by the immutable trigger. Verified at database level (no endpoint returns an order) | Not run |
| TC-46 | negative (extra) | api 4.3 | Reason: catalog changed after review | Deactivate product B; POST with B. Deactivate slot S2; POST with S2. Unknown product uuid | Product: 409 `PRODUCT_UNAVAILABLE`. Slot: 409 `SLOT_UNAVAILABLE`. Nothing stored, no capacity taken | Not run |
| TC-47 | edge (extra) | api 4.3 | Reason: "first failure is returned" order of checks | Bodies with two faults: invalid phone + date too soon; MIN_QTY + DATE_LEAD; DATE_LEAD + wrong total; wrong total + full date; full date + per-phone limit reached; unserved district + MIN_QTY; fault + reused key | Result follows the documented order: validation, idempotency, product/slot/district, MIN_QTY/lead/horizon, price, per-phone, capacity. Record any difference as a defect | Not run |
| TC-48 | negative (extra) | ADR-0014 | Limit 10/hour per IP | 10 POSTs (valid or invalid), then the 11th; then wait/advance clock 1 h | 11th: 429 `RATE_LIMITED` with `Retry-After` (seconds). After the window: accepted. Record whether rejected (4xx) and replayed requests count toward the 10 (Q-A8) | Not run |
| TC-49 | negative (extra) | ADR-0014, BR-1 | Per-phone limit 5 per 24 h. IP limit raised | 5 accepted orders with phone P (also written `+84...` and `0...`); the 6th; then move clock 24 h + 1 min; a 6th for another phone Q | 6th: 429 `RATE_LIMITED`, no capacity taken. After 24 h: accepted. Phone Q unaffected. A cancelled order's effect on the count recorded (Q-A9) | Not run |
| TC-50 | negative (extra) | ADR-0014 | Read limit 120/min | 121 `GET /v1/catalog` in one minute | 121st: 429 with `Retry-After`; `/healthz` follows the read group as documented | Not run |
| TC-51 | negative (extra) | auth 4 | `TRUST_PROXY=false` then true | Send 11 POSTs with changing `X-Forwarded-For` values | With TRUST_PROXY false the header is ignored and the 11th is limited. With true, only the trusted proxy header is used | Not run |
| TC-52 | negative (extra) | api 1 | Reason: body limit | POST of 8 KB, 8 KB + 1 byte, 1 MB body | At or below 8 KB: normal validation. Above: 413 `PAYLOAD_TOO_LARGE`; no crash | Not run |
| TC-53 | negative (extra) | ADR-0014 | `ORDERING_ENABLED=false` | POST a valid order; GET catalog and availability | POST: 503 `ORDERING_PAUSED`, nothing stored. Catalog and availability behaviour recorded (Q-A10) | Not run |
| TC-54 | negative (extra) | FR-17 | Database stopped or connection blocked | POST an order; `GET /v1/catalog`; `GET /healthz`; restore the database; POST again with the same key | 503 `SERVICE_UNAVAILABLE` (not 500, no stack trace); `/healthz` 503 `{"status":"degraded"}`. After restore the same key creates exactly one order | Not run |
| TC-55 | extra | deployment 7 | Normal | `GET /healthz` | 200 `{"status":"ok"}`, `Cache-Control: no-store`, no order data | Not run |
| TC-56 | acceptance | AC-21 | Each error condition reachable | Trigger every code in api.md section 5 | Each error body follows the envelope: `error.code`, `message_key` present, `request_id`, `fields` only for `VALIDATION_FAILED`. Body never contains server-written display text, stack trace, SQL or personal data. Every `message_key` exists in UI section 8 (keys without a UI entry are listed as defects/questions: see Q-C1) | Not run |
| TC-57 | negative (extra) | robustness | Reason: unspecified cases | POST with malformed JSON; `Content-Type: text/plain`; empty body; `PUT /v1/orders`; `GET /v1/orders`; `GET /v1/unknown`; `DELETE /v1/catalog` | A defined 4xx for each (400/404/405/415), error envelope or documented, no 500, no stack trace (see Q-A11) | Not run |
| TC-58 | negative (extra) | auth 6 | Reason: enumeration and data exposure | Try `GET /v1/orders/BT-XXXXXX`, `/v1/staff/orders`, `/v1/orders?phone=...` | 404 (customer orders) and 401 (staff prefix); no customer data returned from any route | Not run |
| TC-59 | acceptance | AC-28, BR-9 | Database level only (no cancellation endpoint). 11-10 filled to 10 by an order O of 2 cakes | `UPDATE customer_order SET status='Cancelled'` for O using the migration role. Read `day_load` and availability | `day_load` 11-10 = 8; an `order_event` row exists; availability for cakes=2 shows 11-10 available again. Cancelling a second time is a no-op: the guard lets a same-status update through, `day_load` is not reduced twice and no second event is written [v1.1 | 2026-10-26] | Not run |
| TC-60 | negative (extra) | order-lifecycle 6 | Reason: state guard | Direct SQL: New to Completed; Completed to New; Cancelled to Confirmed; New to Confirmed to Completed; change `total_cakes` of an order | Invalid pairs rejected by `customer_order_status_guard`; valid ones accepted with events; changes to snapshot columns rejected | Not run |
| TC-61 | regression (extra) | ADR-0008 | After TC-18, TC-19, TC-20, TC-59 | Run the reconciliation query (`day_load.cakes_accepted` versus the sum of `total_cakes` of non-cancelled orders per date) | Equal for every date; CHECK `cakes_accepted <= capacity_limit` holds | Not run |
| TC-62 | edge (extra) | A-1, A-8 | Server in UTC. Clock set to 2026-11-02T17:30:00Z (= 2026-11-03 00:30 shop time) | `GET /v1/catalog`, `GET /v1/availability`, POST an order for 2026-11-05 and for 2026-11-04 | `server_date` is 2026-11-03. First available date is 2026-11-05. Order for 11-04: 422 `DATE_LEAD`. `created_at` is UTC with `Z` | Not run |
| TC-63 | edge (extra) | ADR-0008 | Reason: limit changed in settings | Raise DAILY_LIMIT to 12, check availability and order on a date with existing `capacity_limit` 10; lower it to 5 while 8 cakes are accepted on a date | After raising: remaining uses the current setting (12 minus accepted); order fits. After lowering: that date is `FULL` for all sizes; POST returns `DATE_CAPACITY`; no CHECK violation, no 500 | Not run |
| TC-64 | edge (extra) | AC-16, ADR-0009 | Fixed random source forces the same code twice | Create two orders where the first draw of order 2 equals order 1's code; force 6 consecutive collisions | Collision once: a new code is drawn, order 2 succeeds with another code. Six collisions: 500 `INTERNAL_ERROR`, nothing stored, no capacity taken; retry with the same key succeeds | Not run |
| TC-65 | negative (extra) | auth 6 | Log capture on | Run a successful order, a validation failure and a 500 path with the test names/phones/addresses/notes | Logs contain request id, code, platform and app version only; none of the name, phone, address or note, and no SQL or stack trace in responses | Not run |
| TC-66 | acceptance | AC-29 | Seed loaded | Query tables; call the catalog | Every seed row has `is_sample = true`; the API response has no sample flag; no visible text contains "sample", "demo", "test" (and see Q-S6 about the Vietnamese word "mẫu"); phones and names are the fake values; no real personal data | Not run |
| TC-67 | extra | FR-3, deployment 4 | Normal | `GET /privacy`; `GET /assets/products/<file>` for four products and the logo; a missing asset | Privacy: 200 HTML listing name, phone, address, note, purpose, who sees them, retention placeholder. Assets: 200 with `Cache-Control: public, max-age=86400`; missing: 404 | Not run |
| TC-68 | extra | NFR performance | Staging-like database | 50 parallel valid orders (different dates); measure | All answered within 10 s; p95 under 8 s (alert threshold in deployment.md); also a first request after idle (cold database) recorded | Not run |
| TC-69 | acceptance | AC-2, AC-3 | Seed | Check `phone_contact` and `zalo_contact` in the catalog | `phone_contact` is E.164 and usable in `tel:`; `zalo_contact` is digits in international form (or an account id, Q-A12) and makes a valid `https://zalo.me/<value>` link | Not run |
| TC-70 | negative (extra) | G-2 | Reason: database-level guard independent of code | With the migration role insert into `day_load` a row with `cakes_accepted` above `capacity_limit`; update `customer_order.total_cakes` inconsistent with items | CHECK constraints reject both | Not run |

### 4.2 iOS UI level

All iOS cases run on iPhone simulator iOS 17.x and 26.x unless noted, against the stub backend (E-5) with the seed values in section 1 and the fixed clock. The date fixtures apply to the stub as well.

| ID | Type | Covers | Preconditions | Steps | Expected | Result |
| -- | ---- | ------ | ------------- | ----- | -------- | ------ |
| TC-101 | acceptance | AC-1 | App installed, catalog responds | Cold start the app | A screen with only the logo (no text, button or spinner) shows for at least 1.0 s and at most 2.0 s, then S-2. Nothing tappable on S-1 | Not run |
| TC-102 | acceptance | AC-2 | On S-2, data loaded | Look at S-2 | Shop name, greeting, Zalo button, phone button ("Gọi điện"), "Xem sản phẩm" and "Đặt bánh" visible | Not run |
| TC-103 | acceptance | AC-3 | Real iPhone, Zalo installed; then Zalo not installed | Tap Zalo on S-2 | The link `https://zalo.me/<zalo_contact>` opens (Zalo app if installed, otherwise the browser page). Result recorded for both cases. Blocked on simulator (ADR-0015) | Not run |
| TC-104 | acceptance | AC-3 | Real iPhone (dialer available) | Tap phone on S-2 | Dialer opens with the shop number from `phone_contact` | Not run |
| TC-105 | negative (extra) | AC-3, UI 5.2 | URL opener stubbed to fail | Tap Zalo, then phone, on S-2 and S-9 | Toast `ERR_OPEN_ZALO` / `ERR_OPEN_PHONE`; no crash; the screen stays usable | Not run |
| TC-106 | acceptance | AC-4 | Catalog with 4 products | Tap "Xem sản phẩm" | Exactly 4 cards, each with picture, name, description and price (`{amount}/cái` style per design system) | Not run |
| TC-107 | negative (extra) | UI 5.3 | One image URL broken | Open S-3 and that cake's S-4 | Placeholder in the image frame labelled `PRODUCT_IMG_FAILED`; card still tappable; order button on S-4 still enabled | Not run |
| TC-108 | acceptance | AC-5 | On S-4 of cake B | Tap "Đặt bánh này" | S-5 opens with B at 1, other cakes at 0; total 1, hint `QTY_MIN_HINT` shown, Next disabled | Not run |
| TC-109 | acceptance | AC-6 | S-5 | Set quantities 2, 0, 3, 0 and go through to S-8 | S-8 lists exactly two cakes (quantities 2 and 3) with line prices; zero lines absent | Not run |
| TC-110 | acceptance | AC-7 | Clock D, device date set to other days in other runs | Open S-6 (cakes 2) | Dates before 2026-11-04 are not selectable (dimmed, not focusable, spoken reason `DATE_A11Y_TOO_SOON`); 11-04 selectable. Same at clock D 00:00 and 23:59 | Not run |
| TC-111 | acceptance | AC-8 | Availability stub per fixtures; order of 3 cakes then 2 cakes | Open S-6 | With 3 cakes 11-10 (remaining 2) is struck/unselectable and `DATE_A11Y_FULL`; with 2 cakes 11-10 is selectable; a date with room exactly equal to the order is selectable | Not run |
| TC-112 | acceptance | AC-24 | Clock D | Open S-6, go to last month | No date after 2026-12-02 selectable (`DATE_A11Y_TOO_FAR`); 12-02 selectable if capacity; next-month control disabled at the last month; previous disabled at the first | Not run |
| TC-113 | acceptance | AC-9 | Review reached for 11-10 (2 cakes); stub POST returns 409 `DATE_CAPACITY` | Tap "Xác nhận đơn hàng" | No S-9. Top error shows `ERR_DATE_CAPACITY` with the date; confirm disabled; button `ACTION_CHOOSE_DATE` opens S-6; all entered data kept | Not run |
| TC-114 | acceptance | AC-10 | S-6 | Pick each of the 3 slots with a date selected, and with different dates | Same slot list for every date; Next stays disabled until both date and slot chosen (hint `NEXT_HINT_DATE_TIME`); choosing a slot changes no date's availability | Not run |
| TC-115 | acceptance | AC-11 | S-7 | Open the district picker; choose Q1 then Q2 | Sheet lists only served districts (Q1, Q2), each with its fee; line `DISTRICT_FEE` shows the fee of the choice (20000 then 30000); no "free" wording; Q3 not selectable | Not run |
| TC-116 | negative | AC-12 | S-7 | Tap Next with all empty; then with only phone invalid ("123") | Errors next to each failing field (`ERR_NAME_REQUIRED`, `ERR_PHONE_REQUIRED`, `ERR_ADDRESS_REQUIRED`, `ERR_DISTRICT_REQUIRED`); focus moves to the first failing field; flow does not advance; invalid phone shows `ERR_PHONE_INVALID`; error clears when the field becomes valid | Not run |
| TC-117 | negative | AC-13 | S-5 total 1; then stub S-8 with `MIN_QTY` 422 | Check Next with total 1; then 2 | Total 1: Next disabled, hint states minimum 2. Total 2: no quantity error, Next enabled. (Server `MIN_QTY` path: S-8 shows `ERR_MIN_QTY`, confirm disabled, action returns to S-5.) | Not run |
| TC-118 | acceptance | AC-14 | Prices A 50000, B 60000, fee Q1 20000 | Choose A x2, B x1, district Q1; open S-8 | Total shown 180000 = 100000 + 60000 + 20000; line prices and fee rows shown; whole dong format | Not run |
| TC-119 | acceptance | AC-15 | Valid review; stub POST 201 | Confirm | Only S-9 appears with the order code; no tracking, status or cancel control; stub received name, phone, address, note as entered | Not run |
| TC-120 | acceptance | AC-16 | Stub returns different codes (or test backend) | Place two orders in sequence | The two codes shown differ; codes shown as returned | Not run |
| TC-121 | acceptance | AC-17 | On S-9 | Look; tap Zalo and phone | Both buttons visible and behave as TC-103 / TC-104 (real device) and TC-105 | Not run |
| TC-122 | acceptance | AC-18 | Data on S-5, S-6, S-7 entered; on S-8 | Back through S-7, S-6, S-5 and forward again; also use each Edit control | All quantities, date, slot, name, phone, address, district, note still present at every step | Not run |
| TC-123 | acceptance | AC-19 | Stub with 2 s delay | Double-tap Confirm quickly (and tap 5 times) | Exactly one POST sent; button shows `BTN_SENDING`, disabled; review inert; Edit and back disabled | Not run |
| TC-124 | acceptance | AC-20 | Airplane mode (or stub no connection) | Confirm | No S-9; `ERR_OFFLINE` shown; data kept; retry button works after connection returns and sends the order once | Not run |
| TC-125 | acceptance | AC-21 | All screens and all error states | Walk every screen and trigger every message key in UI section 8 with the device language set to English and to Vietnamese | All text Vietnamese, none in English or showing a raw key; VoiceOver speaks Vietnamese; system-owned strings (back, keyboard, share) recorded | Not run |
| TC-126 | acceptance | AC-22 | Stub returns 409 `DATE_CAPACITY` for one of two customers (real race covered by TC-18) | Confirm | The customer is told the date is no longer available (`ERR_DATE_CAPACITY`) and can choose another date; the other order gets S-9 | Not run |
| TC-127 | acceptance | AC-23 | Stub: first POST returns 409 `PRICE_CHANGED` with new prices | Confirm on S-8 | Review refreshes to the new line prices, fee and total from the 409; `MSG_PRICE_CHANGED` shown; confirm enabled; second confirm sends the new `expected_total_vnd` and S-9 appears. (Stored price check: TC-45) | Not run |
| TC-128 | acceptance | AC-25 | On S-9 | Read the confirmation text | `CONF_MESSAGE`: order received and the shop will contact; the words "đã chấp nhận" / "đảm bảo" / "accepted" absent | Not run |
| TC-129 | edge | AC-26 | S-7 | Type 200 characters; try the 201st; paste 250 characters; leave empty and confirm | 200 accepted and counter 200/200, shown on review; 201st not inserted and `ERR_NOTE_MAX` next to the field; paste cut to 200; empty note: order confirms | Not run |
| TC-130 | acceptance | AC-27 | All screens | Review every screen, string and VoiceOver label for payment words | No payment note, method or instruction anywhere, including S-8 and S-9 and error messages | Not run |
| TC-131 | acceptance | AC-29 | Stub with seed data | View S-2 to S-9 | No visible "sample", "demo" or "test" marker; see Q-S6 | Not run |
| TC-132 | extra | UI 5.2 | Reason: all six states of S-2 | Force Loading (slow stub), Error without cache, Default; disabled buttons | Loading: skeleton, buttons disabled. Error: `HOME_ERR`, retry, all four buttons disabled. Retry reloads. (With a cache the Error state does not appear, ADR-0011) | Not run |
| TC-133 | extra | UI 5.3 | Reason: states of S-3 | Slow, failed, and 3-product responses | Loading: 4 skeleton cards. Error: `PRODUCTS_ERR` with retry. Fewer than 4 products: Error (not 3 cards) | Not run |
| TC-134 | extra | UI 5.4 | Reason: states of S-4 | Data not available at entry; image fail | Loading: skeleton, order button disabled. Failed: Error with retry | Not run |
| TC-135 | extra | UI 5.5 | Reason: states of S-5 | Slow, failed products; total 0 | Loading: skeleton, steppers and Next disabled. Empty (total 0): hint, Next disabled. Minus disabled at 0. Error: `PRODUCTS_ERR`. Plus behaviour at 99 per cake (Q-U2) | Not run |
| TC-136 | extra | UI 5.6 | Reason: states of S-6 | Slow availability; failed availability; all dates unavailable (cakes 11); return to S-5, raise quantity so the chosen date no longer fits | Loading: skeleton, Next disabled. Error: `DATE_ERR` with retry. Empty: every date unavailable, `DATE_EMPTY` and `DATE_EMPTY_ACTION` to S-5. Chosen date cleared, slot kept, `DATE_CLEARED` shown | Not run |
| TC-137 | extra | UI 5.7 | Reason: states of S-7 | District list loading, empty, failed | Loading: picker disabled with spinner, other fields usable, Next treats district as missing. Empty: `DISTRICT_EMPTY`, Next disabled. Failed: `DISTRICT_ERR` with retry | Not run |
| TC-138 | extra | UI 5.8 | Reason: S-8 error and button rules | Drive each rule error (`MIN_QTY`, `DATE_CAPACITY`, `DATE_LEAD`, `DATE_HORIZON`, `DISTRICT_UNSERVED`) and each not-sent error (offline, 500, timeout over 10 s) | Rule errors: message and action button to the right step (S-5, S-6, S-7), confirm disabled, enabled again after fixing. Not-sent errors: message, confirm stays enabled, retry sends again with the same key; data kept; no S-9 | Not run |
| TC-139 | extra | UI 5.9 | Reason: duplicate-send prevention | On S-9 press back gesture; press Home button; tap contact buttons | Back goes to S-2, never S-8; Home clears flow data (new order starts empty); code long-press copies the plain code `BT-XXXXXX` | Not run |
| TC-140 | extra | ADR-0009 | Reason: quantity bounds | Raise one cake to 99 and try to go higher; total over DAILY_LIMIT | Stepper stops at 99 (behaviour per Q-U2); totals correct; S-6 then shows Empty if no date fits | Not run |
| TC-141 | extra | ADR-0011 | Reason: draft survives process death | Fill S-5, S-6, S-7; kill the app; relaunch; tap "Đặt bánh" | S-5 opens with restored items, date, slot, name, phone, address, district, note. Restore on each step S-5 to S-8 | Not run |
| TC-142 | extra | ADR-0011 | Reason: draft lifetime | Draft saved; move clock 23 h 59 min then 24 h 01 min with no change; place an order | Under 24 h: restored. Over 24 h: discarded, empty flow. After a confirmed order: draft deleted | Not run |
| TC-143 | extra | ADR-0011 | Reason: S-4 versus saved draft | Saved draft exists; open S-4 of cake C and tap order | A new draft starts with C at 1 (old draft replaced); no prompt. Compare with UI 5.1/5.4 (Q-U1) | Not run |
| TC-144 | extra | AC-19, ADR-0008 | Reason: unknown outcome | Stub accepts the order but drops the response; kill the app; relaunch; open flow; confirm | Same idempotency key from the draft is sent; the server replays; S-9 shows the same code; one order | Not run |
| TC-145 | extra | ADR-0011 | Reason: offline cache | Load catalog online; go offline; cold start; also with no cache (fresh install) offline | With cache: S-2, S-3, S-4 show cached data, no error. No cache: `HOME_ERR`. S-6 offline: `DATE_ERR` | Not run |
| TC-146 | extra | ADR-0011 | Reason: cache lifetime | Cache 6 d 23 h old, then 7 d 1 h old, offline | Under 7 days shown; older counts as no cache (Error state) | Not run |
| TC-147 | extra | PRD NFR accessibility | Reason: Dynamic Type | Largest accessibility text size on S-2 to S-9 | Text scales; no clipped text; steppers stack; calendar cells grow; bottom bar never covers content; contact buttons usable | Not run |
| TC-148 | extra | UI 9 | Reason: VoiceOver | Walk the flow with VoiceOver in Vietnamese | Every control has a label (steppers `QTY_*_A11Y`, back, order code `CONF_CODE_A11Y`); dates speak state and reason; field errors announced and linked; banners announced as alert; focus moves to first invalid field | Not run |
| TC-149 | extra | UI 9 | Reason: contrast and targets | Measure text contrast on glass and on fallback; touch target sizes | Body text at least 4.5:1; targets at least 44 pt; selected vs unavailable dates differ by more than colour | Not run |
| TC-150 | extra | UI 7, ADR-0012 | Reason: Reduce Motion and Reduce Transparency | Turn each on | Reduce Motion: 150 ms cross-fades only. Reduce Transparency: `material.fallback` surfaces, layout unchanged | Not run |
| TC-151 | extra | ADR-0005, 0012 | Reason: OS spread | Run TC-102, TC-110, TC-118, TC-119 on iOS 17.x and 26.x | Same behaviour; iOS 17 uses fallback surfaces, iOS 26 uses Liquid Glass; no crash from unavailable APIs on iOS 17 | Not run |
| TC-152 | extra | A-1 | Reason: device in another time zone | Set device time zone to UTC-8 and UTC+9 | Dates shown and selected follow shop time (server date), not device time zone | Not run |
| TC-153 | extra | A-8 | Reason: wrong device clock | Set device date to 5 days ahead, then 5 days behind | Date grid still built from `server_date`; an order is accepted or rejected by the server rules only (see Q-U3) | Not run |
| TC-154 | extra | UI 5.10 | Reason: loss of connection while picking | Go offline on S-6 and S-7 (districts), then back online | `DATE_ERR` / `DISTRICT_ERR` with retry; entered data kept; no automatic send; retry reloads only the failed data | Not run |
| TC-155 | extra | api 5 | Reason: error-code mapping | Stub each code: `VALIDATION_FAILED` (field list), `DATE_LEAD`, `DATE_HORIZON`, `DISTRICT_UNSERVED`, `PRODUCT_UNAVAILABLE`, `SLOT_UNAVAILABLE`, `IDEMPOTENCY_KEY_REUSED`, `RATE_LIMITED` (with Retry-After), 413, `ORDERING_PAUSED`, 503, 500, unknown code | Each maps to the UI behaviour in api.md section 5; unknown codes behave as 500 (`ERR_SERVER` with retry); `IDEMPOTENCY_KEY_REUSED`: new key and one retry then `ERR_SERVER`; field errors from the server appear next to the field and return to S-7. Keys missing in UI (Q-C1) recorded | Not run |
| TC-156 | extra | ADR-0014 | Reason: rate-limit UX | Stub 429 with Retry-After 3600 | Customer sees a message (currently `ERR_SERVER`); data kept; retry before the time is blocked or explained (Q-U4) | Not run |
| TC-157 | extra | FR-16, UI 5.8 | Reason: app state change while sending | Confirm, send the app to background, return after reply; lock the screen; lose connection mid-request | Result applied on return (S-9 or error); no second order; timeout after 10 s shows `ERR_TIMEOUT` and the same key is used for retry | Not run |
| TC-158 | extra | UI 5.7, ADR-0009 | Reason: input limits and keyboards | Paste 300-character name and 400-character address; phone pad; autofill; return key flow | Inputs limited to 100 and 250 (behaviour with feedback per Q-U5); phone pad shown; return moves to next field; note return inserts newline | Not run |
| TC-159 | extra | PRD NFR privacy | Reason: privacy sentence before confirm | Open S-8 | `REVIEW_PRIVACY` visible before the confirm button; compare content with collected data (the note is collected, Q-U6) | Not run |
| TC-160 | extra | FR-15 | Reason: navigation loops | Repeat Edit and forward 10 times across all steps; change cakes after choosing a date; change district after review | No data loss or duplicate entries; totals and fee recomputed; S-6 re-checks the date; S-8 shows fresh values | Not run |
| TC-161 | extra | ADR-0009 | Reason: Vietnamese and special input | Enter names with diacritics (composed and decomposed from the keyboard), emoji, apostrophes, very long words | Accepted or rejected consistently with the server rules (TC-30, TC-31); no crash; review shows the same text | Not run |
| TC-162 | extra | ADR-0011 | Reason: backup exclusion | Inspect the draft file attributes | Draft file excluded from backup, complete data protection; deleted after success | Not run |
| TC-163 | extra | auth 6 | Reason: transport | Inspect app transport settings; point the app to an http URL | Cleartext blocked (ATS default); only https used | Not run |
| TC-164 | extra | G-1 | Reason: step count | From S-2, place an order with a stopwatch and count taps | At most 4 steps plus confirmation after "Đặt bánh" (limit 6); no account or login prompt anywhere | Not run |
| TC-165 | extra | UI 5.1 | Reason: launch timing | Launch with a fast and with a very slow (5 s) catalog | S-1 shows 1.0 to 2.0 s; then S-2 in Loading state if data is slow; no spinner or text on S-1 (see Q-U7) | Not run |

### 4.3 Android UI level

Each Android case repeats the iOS case with the same number minus 100 plus 200 (TC-2nn mirrors TC-1nn): same preconditions, steps and expected result, with the platform changes below. Mirrored: TC-201 to TC-231 (acceptance and edge, mirror of TC-101 to TC-131), TC-232 to TC-265 (extra, mirror of TC-132 to TC-165). Android-only cases follow.

| ID | Mirror of | Platform changes to apply | Result |
| -- | --------- | ------------------------- | ------ |
| TC-201 to TC-231 | TC-101 to TC-131 | Compose UI tests; emulator API 26 and API 34 or newer; Material 3 Expressive components (`ButtonGroup` stepper, modal bottom sheet for districts). TC-203 / TC-204 on a real phone via intents (`https://zalo.me/...`, `tel:`); TC-205 intent fails (no handler); TC-225 uses device language English and Vietnamese; TC-210 and TC-212 also with device date/time zone changed | Not run |
| TC-232 to TC-265 | TC-132 to TC-165 | TC-247 and TC-248: TalkBack and 200% font scale (replace VoiceOver and Dynamic Type); TC-250: "Remove animations" and reduced transparency; TC-251: API 26, API 30 (opaque fallback) and API 31+ (blur); TC-262: `no_backup` directory / backup rules; TC-263: `usesCleartextTraffic=false`; TC-249: touch target 48 dp | Not run |

Android-only extra cases:

| ID | Type | Covers | Preconditions | Steps | Expected | Result |
| -- | ---- | ------ | ------------- | ----- | -------- | ------ |
| TC-266 | extra | UI 5.9, FR-16 | Reason: system back behaviour (UI section 6) | On S-9 press system back and use predictive back gesture; on S-8 press back during sending; on S-5 (entered from S-2) press back | S-9 back goes to S-2, never S-8. Back during sending is ignored or safe (no second send, no lost result; behaviour per Q-U8). Back from step 1 returns to the previous screen and the draft behaviour matches Q-U1 | Not run |
| TC-267 | extra | UI, NFR | Reason: activity recreation, "Don't keep activities", rotation, split-screen, process death with low memory | Rotate the phone on each screen (orientation is not specified, Q-U9); enable "Don't keep activities"; use `adb shell am kill` on each step; change language and font size while on S-7 | No data lost, no duplicate order, no crash; the draft restore follows ADR-0011; layout survives rotation if allowed | Not run |

### 4.4 Slice 0 executable tests [v1.1 | 2026-10-26]

Executable QA package: `backend/Tests/qa/` (own `Package.swift`; compiles `backend/Sources/App` through a symlink without `entrypoint.swift`; run `cd backend/Tests/qa && swift test`; for database tests add `DATABASE_MIGRATION_URL=postgres://...` of a throwaway database). Developers' own tests (`backend/Tests/AppTests`, 26 tests) are not mine; they were run once: 26 pass on f940495.

Plan cases that belong to slice 0 and how they are covered (all other plan cases wait for slices 1 to 3):

| Plan case | Slice-0 part | QA test (class.method) | Result on f940495 |
| --------- | ------------ | ---------------------- | ----------------- |
| TC-55 | `/healthz` 200 `{"status":"ok"}`, no-store | HealthEdgeTests.testShallowBodyIsExactlyStatusOk, testFixturesMatchWireFormat | Pass |
| TC-54 (health part) | deep check 503 degraded when database fails; real stopped database | HealthEdgeTests.testDegradedBodyAndHeaders, testRecoveryAfterFailureNoStickyState (stub); real database stop | Pass (stub); real DB Blocked |
| TC-59 | cancel releases capacity, event written, second cancel changes nothing | DatabaseTests.testCancelReleasesCapacityOnceAndWritesEvent | Not run (no PostgreSQL) |
| TC-60 | transition matrix (4 valid, 8 invalid), snapshot columns immutable | DatabaseTests.testStatusTransitionMatrix, testSnapshotColumnsAreImmutable, testPersonalColumnsChangeOnlyThroughPurge | Not run (no PostgreSQL) |
| TC-61 | reconciliation after cancel | DatabaseTests.testReconciliationHoldsAfterCancels | Not run (no PostgreSQL) |
| TC-66 | all seed rows `is_sample = true`; no visible marker text | DatabaseTests.testSeedRowsAreAllMarkedSample; RepositoryLayoutTests.testSeedHasNoSampleMarkerInVisibleText | static: Pass; DB: Not run |
| TC-69 | seed `phone_contact` E.164 (CHECK accepts the seed insert) | DatabaseTests.testSeedIsIdempotentAndEverythingIsSample (inserts under the CHECKs) | Not run (no PostgreSQL) |
| TC-70 | CHECK, UNIQUE, FK guards at database level | DatabaseTests.testCheckConstraintsRejectBadRows (26 bad rows), testIdempotencyKeyAndOrderCodeAreUnique, testItemChecksAndRestrictiveForeignKeys, testOrderEventIsAppendOnly | Not run (no PostgreSQL) |

Slice-0 extra cases (`extra`, reasons in the Notes column), numbered TC-71 and up:

| TC | Type | Test | Notes (reason) | Result |
| -- | ---- | ---- | -------------- | ------ |
| TC-71 | extra | HealthEdgeTests.testDeadlineIsAboutTwoSeconds, testFastSuccessDoesNotWaitForDeadline | Deep timeout is 2 s (api.md 4.4), not early, not late | Pass |
| TC-72 | extra | HealthEdgeTests.testManyParallelDeepChecksWithSlowDatabase | 25 parallel deep checks with a hung database: all 503 in under 5 s, none queue | Pass |
| TC-73 | extra | HealthEdgeTests.testDeepQueryVariants, testOnlyGetIsServed, testHeadRequestDoesNotFailLikeAServerError, testTrailingSlashAndCase | Odd queries stay shallow; POST/PUT/DELETE/PATCH not 200 and not 5xx; HEAD (used by many uptime monitors) 200; `/healthz/` 200 | Pass |
| TC-74 | extra | HealthEdgeTests.testErrorDetailsNeverLeakIntoResponse | Probe error text with credentials never reaches the body | Pass |
| TC-75 | extra | ConfigEdgeTests (8 non-defect tests) | Port boundaries, whitespace, case sensitivity, pool max, values never echoed in errors | Pass |
| TC-76 | extra | ConfigEdgeTests.testDefectMigrateNeedsOnlyTheMigrationRole | `migrate` with only APP_ENV and DATABASE_MIGRATION_URL (what the staging deploy job passes) | **Fail** (D-2) |
| TC-77 | extra | ConfigEdgeTests.testDefectTrailingNewlineIsTrimmed | Secret pasted with trailing newline | **Fail** (D-5) |
| TC-78 | extra | SplitterEdgeTests (12 non-defect tests) | Empty input, CRLF, comment and dollar markers inside strings, `$1`, unterminated input, Vietnamese text, 20 000 statements under 5 s | Pass |
| TC-79 | extra | SplitterEdgeTests.testDefectEscapeStringWithBackslashQuote, testDefectQuotedIdentifierWithSemicolon, testDefectNestedBlockComment | Valid PostgreSQL the scanner cuts wrongly | **Fail** x3 (D-4) |
| TC-80 | extra | DatabaseTests.testMigrationRerunIsNoOpAndSchemaIsComplete, testRevertIsRefused, testFailingMigrationLeavesNothingBehind | Re-run is a no-op (ledger), 9 tables and 4 triggers, revert refused, a failing file leaves no table | Not run (no PostgreSQL) |
| TC-81 | extra | DatabaseTests.testSeedIsIdempotentAndEverythingIsSample | Seed twice (and a third time) gives identical row counts | Not run (no PostgreSQL) |
| TC-82 | extra | DatabaseTests.testActorSettingsAreRecordedInTheEvent, testBogusActorTypeFailsTheUpdateAtomically, testCompletionAndConfirmationDoNotTouchCapacity, testCancelWithMissingDayLoadRowDoesNotFail, testCancelThatWouldMakeCounterNegativeIsBlockedAndAtomic, testPaymentStatusStaysMutable, testBlankPersonalDataWithoutPurgeMarkerIsRejected | Trigger edge behaviour: actor settings, atomic failure, no day_load row, counter would go negative | Not run (no PostgreSQL) |
| TC-83 | extra | RepositoryLayoutTests.testMonorepoComponentsExist, testMigrationNumberingHasNoGapsOrDuplicates, testMigrationsAreForwardOnlyAndFreeOfDestructiveStatements, testSeedNeverDeletesOrUpdates | Layout (ADR-0004) and migration hygiene | Pass |
| TC-84 | extra | RepositoryLayoutTests.testDockerfileCopiesEveryTargetPathOfPackageSwift | Image build context holds every path Package.swift declares (verified separately: `swift package describe` in a copy without `Tests/` fails with "invalid custom path 'Tests/AppTests'") | **Fail** (D-1) |
| TC-85 | extra | RepositoryLayoutTests.testEnvExampleCoversEveryVariableWorkflowsAndComposeUse, testWorkflowsDeclareLeastPrivilegeAndNoPullRequestTarget, testSecretsAreOnlyReferencedByMainOnlyJobs, testNoCredentialLookingValuesCommitted | `.env.example` names only; workflows read-only permissions, no `pull_request_target`; secrets only in the push-only deploy job; no credential patterns outside throwaway placeholders | Pass |
| TC-86 | extra | (manual review, no test) | Workflow gaps found by reading: D-3, D-6, D-7, D-8 | see Defects |
| TC-87 | extra | iOS and Android shells | Configuration read only: iOS deployment target 17.0, bundle id `app.banh.customer`, iPhone only; Android minSdk 26, applicationId `app.banh.customer` (ADR-0005, ADR-0016 agree). Shell builds not run here (iOS workflow needs Xcode 27 runner; Android needs SDK 37) | Blocked (build), config Pass |

Not covered in slice 0 and why: real concurrent double-cancel (needs committed data and two connections; plan TC-19/TC-20 style, add when PostgreSQL is available), Docker image run (no Docker), deploy job (needs secrets), real database stop for TC-54.

## 5. Additional Cases

Cases marked `extra` above were added by the tester beyond the 29 ACs. Reasons are in the Preconditions column of each case (boundary at exactly N=2, 1 lead days, 30 days ahead, quantity 2 and 1, daily-limit exact fit and one-over; two orders racing for the last cakes; duplicate submit with one key; rate limit and per-phone limit; every API error code; price change; offline, cache and draft; six UI states per screen; accessibility; Vietnamese text; time zone and clock; logs and enumeration; database guards). Android-only extras are TC-266 and TC-267.

## 6. Rounds

| Round | Date | Build | Pass | Fail | Blocked | Not run |
| ----- | ---- | ----- | ---- | ---- | ------- | ------- |
| 0 (plan, early mode) | 2026-10-25 | none (no code) | 0 | 0 | 0 | all |
| 1 (slice 0, execute) [v1.1 | 2026-10-26] | 2026-10-26 | f940495, host tests only | 41 QA + 26 developer = 67 | 6 (QA, all mapped to D-1, D-2, D-4, D-5) | 0 run-blocked; 21 database tests skipped (no PostgreSQL), iOS and Android shell builds not run | slice 1 to 3 cases (unchanged) |

Round 1 detail: QA package 68 tests = SplitterEdge 15 (3 fail), ConfigEdge 10 (2 fail), HealthEdge 12 (0), RepositoryLayout 10 (1 fail), Database 21 (skipped). 47 executed, 41 pass, 6 fail. CI on GitHub (reported by the orchestrator, not observed by me): backend `test` job passed including migrations and seed twice on postgres:16; image, iOS and Android jobs failed.

Counts per level in this version: see section 9 (Change log).

## 7. Defects

[v1.1 | 2026-10-26] Observed on f940495. Document-level findings from the early pass remain Open Questions in section 9.

| ID | Severity | Route | Status | Description |
| -- | -------- | ----- | ------ | ----------- |
| D-1 | High | dev | Open (fix in flight) | Image build fails. `backend/Dockerfile` copies `Package.swift`, `Sources` and `db` but not `Tests/AppTests`, which `Package.swift` declares as test target path. Steps: copy Package.swift, Package.resolved, Sources and contracts to an empty folder; `swift package describe`. Expected: resolves. Actual: `error: invalid custom path 'Tests/AppTests' for target 'AppTests'`. Test: RepositoryLayoutTests.testDockerfileCopiesEveryTargetPathOfPackageSwift. Blocks the slice done criterion "the image runs on the host". |
| D-2 | High | dev | Open | `App migrate` cannot run with the variables the staging deploy job gives it. `AppConfig(variables:)` always requires `PORT`, and `DATABASE_URL` when `APP_ENV` is not `local`, but `deploy-staging` runs `docker run -e APP_ENV=staging -e DATABASE_MIGRATION_URL ... migrate --yes`. Expected: migration needs only the migration URL (the role separation in deployment.md section 3). Actual: exits with "Missing required environment variable PORT", and then `DATABASE_URL`. CI `test` passes only because it sets `APP_ENV=local` and `PORT`. First staging deploy with secrets set will fail before the deploy hook. Test: ConfigEdgeTests.testDefectMigrateNeedsOnlyTheMigrationRole. |
| D-3 | Medium | dev | Open | `backend.yml` uses `concurrency: cancel-in-progress: true` per ref for the whole workflow, including the main-only deploy job. A second push to main cancels a running deploy between "run migrations" and "trigger deploy", leaving the schema ahead of the running code (and a cancelled image push). Expected: the deploy job in its own concurrency group with `cancel-in-progress: false`. Found by review. |
| D-4 | Low | dev | Open | SQL splitter cuts valid PostgreSQL wrongly: escape strings `E'it\'s; x'`, double-quoted identifiers containing `;`, nested `/* /* */ */` comments. Current migration and seed use none of them, so no failure today; a later migration could silently be split into broken statements. Expected: handled, or a documented rule and a test that fails when a migration file uses them. Tests: SplitterEdgeTests.testDefect* (3). |
| D-5 | Low | dev | Open | Config values are trimmed of spaces and tabs only; `PORT="8080\n"` (typical when a value is pasted into a secret store) fails with "Invalid value". Expected: newline trimmed too. Test: ConfigEdgeTests.testDefectTrailingNewlineIsTrimmed. |
| D-6 | Low | dev | Open | Deploy smoke check: the deep check runs once with the 2 s database deadline right after a deploy; a suspended Neon database resumes in 0.5 s to a few seconds (deployment.md), so the job can fail on a healthy system. Expected: retry the deep check for a short period (like the shallow loop). Found by review. |
| D-7 | Medium | dev (with atlas-architect) | Open, needs answer | `ios.yml` uses `runs-on: xcode-27`, not a GitHub-hosted label. If this is a self-hosted runner on a public repository, any pull request (including from forks) runs arbitrary code on the owner's machine. Expected: documented runner choice (deployment.md) and, for self-hosted, no fork pull requests (approval required, or `pull_request` limited to same-repo branches). Found by review; I cannot see the runner configuration. |
| D-8 | Low | dev | Open | Deploy trigger builds the URL as `"${RENDER_DEPLOY_HOOK_URL}&imgRef=${IMAGE}"`; this assumes the hook URL already has a query string, and `IMAGE` contains `:` and `/` unencoded. Expected: documented format of the secret or a robust join. Found by review. |

Not defects (recorded for information): the guard `customer_order_status_guard` allows an update that leaves the status unchanged, so a second `Cancelled` update is a no-op (no second event, no second capacity release) rather than "rejected" as TC-59 said; TC-59 is reworded accordingly (document change, v1.1). The seed uses `ON CONFLICT (id) DO NOTHING`, so an edited sample value is not updated on re-run (acceptable, by design). CI does not run the QA package; adding `swift test` in `backend/Tests/qa` with the database URL (route dev) would run the database tests that were unrun here.

## 8. Verdict

[v1.1 | 2026-10-26] Slice 0, round 1, commit f940495: **Fail**. Two high-severity defects are open (D-1 image build, D-2 migrate configuration) and the database-level tests (TC-59, TC-60, TC-61, TC-66, TC-70) are unrun because this host has no PostgreSQL, so no Pass is claimed for AC-28. The health endpoint, configuration validation, splitter and layout checks that could run pass apart from the defects listed. Whole-feature verdict (below) is still not given.

Whole feature: Not yet given. No test has been run. A verdict of Pass requires all Must ACs (AC-1 to AC-16, AC-18 to AC-27, AC-29; AC-17 and AC-26 follow Should requirements FR-12 and FR-18; AC-28 is Must-relevant only at database level) to pass on API, iOS and Android, and no high-severity defect open. AC-3 and AC-17 (real Zalo and dialer) need devices and will stay `Blocked` until then.

## 9. Open Questions / Change log

Review of the whole document set (PRD v1.2, UI v1.0, system docs v1.0, ADRs). Class is business or technical. `Blocking` means blocking for test design or for test execution. The questions are grouped by who should answer. None is blocking to approve the PRD.

### 9.1 Requirements questions (scribe-requirements and owner)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-S1 | PRD section 12 still lists Q-T1 to Q-T6 as "Open (architect)" while ADR-0008, 0009, 0011, 0013, 0014, 0015 answer them. Update the status and cross-reference. | Keeps the approved PRD consistent; test basis (phone format, order code, idempotency) comes from ADRs, not from the PRD. | No | technical | Open (scribe-requirements) | |
| Q-S2 | AC-12 says "not a valid number" and A-6 "Vietnamese format". ADR-0009 accepts only mobile numbers (landlines and foreign numbers rejected). Is that the intended business rule? A customer with only a landline cannot order. | AC-12 test data (TC-28, TC-29) and customer reach. | No | business | Open (owner via scribe-requirements) | |
| Q-S3 | BR-4 says "no maximum per order other than the remaining amount", but ADR-0009 caps one cake at 99 (and availability at 396). Accept the technical cap, or state it in the PRD? | A tester cannot fail or pass an order of 100 of one cake without knowing. | No | business | Open (scribe-requirements) | |
| Q-S4 | AC-23 "a confirmed order still shows the price at confirmation": no screen or endpoint shows a stored order (S-9 has no prices; no read endpoint). Is a database-level check (TC-45) acceptable evidence? | AC-23 is untestable through the product. | No | business | Open (scribe-requirements) | |
| Q-S5 | AC-28 says testable only once cancellation exists, but order-lifecycle.md creates the trigger now and says AC-28 is testable at database level. Which one counts for this slice? | Whether AC-28 can be Pass or only Blocked at verdict time. | No | business | Open (scribe-requirements) | |
| Q-S6 | AC-29 forbids a visible "sample" marker, but the sample values in api.md use the word "mẫu" (sample): "Tiệm Bánh Mẫu", "Quận Mẫu 1", "Mô tả mẫu", "Đường Mẫu". These would appear in the app and look like a marker. Which sample wording is allowed? Define what counts as a "visible sample marker". | AC-29 pass/fail (TC-66, TC-131). | No | business | Open (scribe-requirements; seed text by forge-dev) | |
| Q-S7 | G-3 says every customer can quote the code, but after the app is closed the code is lost (no order lookup, no list, no history, S-9 not restorable). Is that acceptable for this slice? Should the code be copyable/kept somewhere? | Customer loses the only handle to the order. | No | business | Open (owner) | |
| Q-S8 | AU-Q1 (ADR-0014): 5 accepted orders per phone per 24 h. Does a cancelled order count? Is the limit acceptable for a family ordering several times? | TC-49 expected values. | No | business | Open (owner) | |
| Q-S9 | BR-12: no retention period. The device draft (24 h) and backups also hold personal data. Untestable until a period exists; confirm that no test is expected in this slice. | BR-12 has no AC. | No | business | Open (owner) | |
| Q-S10 | Privacy (PRD NFR): "tell the customer what is collected and why before confirmation". UI `REVIEW_PRIVACY` names name, phone, address only; the note is also collected, and a draft is kept on the device. The first data entry (S-7) comes before the sentence (S-8). Sufficient? | PRD NFR cannot be marked Pass without a rule. | No | business | Open (scribe-requirements) | |
| Q-S11 | FR-9 lists the content of the review; AC-14 only tests the total. Is the order of the lines or the format of money and dates (for example `{date}`) a requirement? Date display format is in neither the PRD nor the UI. | Tests compare text; which format is correct? | No | business | Open (scribe-requirements, canvas-ui) | |
| Q-S12 | AC-21 "any screen or error message is Vietnamese": system-owned text (OS back label, keyboard, share sheet, permission alerts, store text) follows the device language. Is only app-owned text in scope? | Makes AC-21 testable. | No | business | Open (scribe-requirements) | |
| Q-S13 | AC-1 requires "only the logo", UI adds 1.0 to 2.0 s (proposed). Treat the numbers as requirements or as tolerance? | TC-101, TC-165 limits. | No | business | Open (scribe-requirements, canvas-ui) | |
| Q-S14 | Verdict rule: "all Must ACs pass". AC-17 (FR-12 Should), AC-26 (FR-18 Should) are tied to Should requirements. Confirm that failing them does not block a Pass verdict. | Verdict criteria. | No | business | Open (scribe-requirements) | |

### 9.2 UI questions (canvas-ui)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-U1 | Contradiction: UI 5.1 says leaving S-5 with back discards flow data, S-9 Home clears it, and S-2 "Place order" goes to S-5 with no cake chosen. ADR-0011 persists the draft on every change, restores it when "Place order" is tapped, and replaces it silently when a cake detail starts an order. Which is right, and is a silent loss of a restored draft acceptable? | FR-15 tests TC-122, TC-141, TC-143, TC-266. | No | technical | Open (canvas-ui, atlas-architect) | |
| Q-U2 | The stepper maximum is not in the UI (TQ-5 answered by ADR-0009: 99). What happens at 99 (plus disabled? message?) | TC-135, TC-140. | No | technical | Open (canvas-ui) | |
| Q-U3 | Which date does the app use as "today": device date or `server_date` from the API? UI 5.6 says "today"; api.md says clients use `server_date`. | TC-153; device clock wrong. | No | technical | Open (canvas-ui) | |
| Q-U4 | Keys missing: `ERR_PRODUCT_UNAVAILABLE`, `ERR_SLOT_UNAVAILABLE`, `ERR_RATE_LIMITED` (API-Q1). With 429 and Retry-After up to an hour, `ERR_SERVER` ("try again") misleads. Which text and behaviour? | TC-155, TC-156. | No | technical | Open (canvas-ui) | |
| Q-U5 | Input limits for name (100) and address (250): what feedback does the customer get when typing or pasting beyond the limit (silent cut, counter, message)? No message key exists. Also IDEMPOTENCY and `VALIDATION_FAILED` fields other than the listed keys show `ERR_SERVER` on S-7: acceptable? | TC-158, TC-30. | No | technical | Open (canvas-ui) | |
| Q-U6 | `MSG_PRICE_CHANGED` is still PENDING; owner decision is now final (409 `PRICE_CHANGED`, customer re-reviews). Final text; does the review highlight changed lines; is confirm enabled at once; does the retry use the same idempotency key? | TC-127, TC-43. | No | technical | Open (canvas-ui) | |
| Q-U7 | S-2 Error state disables all four buttons, but ADR-0011 serves cached data and only shows Error without cache. Update UI 5.2 and 5.3 to the cache rules (TQ-3, TQ-7 answered). What does S-1 wait for: nothing, or the catalog? | TC-132, TC-145, TC-165. | No | technical | Open (canvas-ui) | |
| Q-U8 | Android system back (and predictive back) during sending on S-8, and during the S-8 inert state: ignored or cancel? iOS swipe-back is disabled during sending? | FR-16 on Android, TC-266. | No | technical | Open (canvas-ui) | |
| Q-U9 | Orientation: portrait-only or rotation allowed on Android? Tablets and foldables? UI is silent (ADR-0005 says iPhone only for iOS). | TC-267. | No | technical | Open (canvas-ui) | |
| Q-U10 | After a draft restore the date may be past or full, prices stale. Does the app re-check the restored date and prices on entry to S-6 and S-8, and does it show `DATE_CLEARED`? | TC-141, TC-142. | No | technical | Open (canvas-ui, atlas-architect) | |
| Q-U11 | Placeholders `{from}` and `{to}` in `DATE_HINT_RANGE` are not in the placeholder list (UI section 1). Format of dates in `{date}` messages (weekday?)? | Text assertions. | No | technical | Open (canvas-ui) | |
| Q-U12 | Unavailable date styling: a date that is both too soon and full, or beyond the horizon — which style and spoken reason? (see also Q-A4) | TC-10, TC-110, TC-111. | No | technical | Open (canvas-ui) | |

### 9.3 Architecture and API questions (atlas-architect)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-A1 | Contradiction: architecture.md names TypeScript, Node.js, Fastify, zod; ADR-0001 to 0004 and ADR-0005, ADR-0010 are still "Proposed". The owner decided Swift Vapor, PostgreSQL, iOS 17, API 26 and the 409 price rule. Update architecture.md, ADRs, api.md (remove "pending" notes), order-lifecycle.md and repository layout (`ios/`, `backend/`). | Test tooling, commands, fixtures and CI depend on the stack. | Yes (for execution) | technical | Open (atlas-architect) | |
| Q-A2 | Is there a time between catalog fetch and order for `settings` (lead days etc.) to change? Are `settings` and `max_qty_per_cake` used by the apps instead of constants? | UI uses `{min}`, `{days}`, `{max}` from configuration. | No | technical | Open (atlas-architect) | |
| Q-A3 | `GET /v1/availability` with unknown query parameters (for example `slot_id`): ignored or `VALIDATION_FAILED`? The rule "unknown fields rejected" is stated for requests (bodies) only. | TC-8, TC-9. | No | technical | Open (atlas-architect) | |
| Q-A4 | Reason precedence in availability when several reasons apply; `TOO_FAR` is defined but never returned in the list (dead value); is the list for dates beyond horizon absent by design? | TC-10; untestable enum value. | No | technical | Open (atlas-architect) | |
| Q-A5 | Unknown (never existing) `district_id`: `DISTRICT_UNSERVED` 422 or `VALIDATION_FAILED`? Unknown product/slot are 409, unknown district 422: why the difference? | TC-26, TC-46. | No | technical | Open (atlas-architect) | |
| Q-A6 | `Idempotency-Key` must be a UUID v4: is v1 or other version rejected? Is `X-App-Version` validated as semver? Is there a minimum supported app version / force-update path (api.md section 6 gives none)? | TC-40. | No | technical | Open (atlas-architect) | |
| Q-A7 | Is `expected_total_vnd` part of the normalised request hash for idempotency? After `PRICE_CHANGED` the client retries with a new total: same key or new key? If an order exists and a replay arrives with a changed total, is it replay or `IDEMPOTENCY_KEY_REUSED`? | TC-41, TC-43. | No | technical | Open (atlas-architect) | |
| Q-A8 | Rate limits are checked before the idempotency lookup (check order step 1 before 3). A legitimate retry after a timeout can get 429 or 503 `ORDERING_PAUSED` instead of the stored order. Intended? Do rejected requests count to the 10 per hour? Carrier-grade NAT puts many customers behind one IP (not researched); is 10 per hour per IP too low? | TC-42, TC-48; honest customers blocked. | No | technical | Open (atlas-architect) | |
| Q-A9 | Per-phone limit "5 accepted orders per 24 h": window rolling or calendar day; do cancelled orders count; is it checked before capacity inside the same transaction (race of two orders for the 5th slot)? | TC-49. | No | technical | Open (atlas-architect) | |
| Q-A10 | With `ORDERING_ENABLED=false`, do catalog and availability still answer, and what does the app show (message `ERR_SERVER` only)? Customer cannot tell that the shop is closed for ordering. | TC-53. | No | technical | Open (atlas-architect, canvas-ui) | |
| Q-A11 | Unspecified error cases: malformed JSON, wrong Content-Type, empty body, unsupported method, unknown path (envelope and codes), `expected_total_vnd` missing/negative/non-integer, unknown `Accept`. Add codes. | TC-57. | No | technical | Open (atlas-architect) | |
| Q-A12 | `zalo_contact`: "digits in international form, or an official account id" — two formats; which one for the seed, and the validation rule for the value? | TC-69, AC-3. | No | technical | Open (atlas-architect) | |
| Q-A13 | `server_date` and the order date use the shop time zone (Asia/Ho_Chi_Minh). How is the clock made injectable for tests (E-1), and is the test hook excluded from production builds? | All date-rule cases. | Yes (for execution) | technical | Open (atlas-architect, forge-dev) | |
| Q-A14 | The capacity row lock plus a per-phone check: a deadlock or long wait is described as impossible; confirm the timeout when the lock waits (client timeout 10 s, server timeout?) and the behaviour when the lock wait times out. | TC-19 under load. | No | technical | Open (atlas-architect) | |
| Q-A15 | Reconciliation query and the "CHECK `cakes_accepted <= capacity_limit`" after the limit is lowered (TC-63): is `capacity_limit` updated in the same UPDATE as stated, and can the row violate the CHECK after a limit decrease? | TC-63, TC-70. | No | technical | Open (atlas-architect) | |
| Q-A16 | Store-side requirements (S-3 unverified) and privacy page: is `/privacy` linked from the app? UI has no link. | TC-67. | No | technical | Open (atlas-architect, canvas-ui) | |

### 9.4 Developer questions (forge-dev)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-P1 | Provide the dev guide and update `CLAUDE.md` (it describes the iOS 15 multiplatform template and ddagent, with no backend or Android). Which commands run backend, iOS and Android unit, integration and UI tests? | Section 1 cannot name commands. | Yes (for execution) | technical | Open (forge-dev) | |
| Q-P2 | Confirm environment items E-1 to E-12 (clock, seed, flags, hooks for collisions and database failure, stub backend, accessibility ids, fixtures). | Without them most edge cases cannot run. | Yes (for execution) | technical | Open (forge-dev) | |
| Q-P3 | Seed text: avoid the word "mẫu" and any visible sample marker in app-visible values (Q-S6) while keeping `is_sample = true` in the data source. | AC-29. | No | technical | Open (forge-dev) | |
| Q-P4 | Which server-side logs exist for TC-65 and can a test read them? | No personal data in logs. | No | technical | Open (forge-dev) | |

### 9.5 Cross-document items observed (no question, for information)

- AC-3 and AC-17 (opening Zalo and the dialer) cannot be executed on simulators; real-device results are required before release (ADR-0015, deployment.md launch checklist).
- AC-16 (unique codes) cannot be proven by sampling; unique index plus TC-14 and TC-64 are the evidence.
- UI "Error" states for S-9 contact buttons depend on the OS reporting a failed open; behaviour with Zalo not installed is not an error (opens a web page).
- design-system.md was not reviewed in detail in this early pass.

### Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.1 | 2026-10-26 | Round 1, slice 0 (execute mode) on f940495: section 4.4 (slice-0 mapping, TC-71 to TC-87), QA package `backend/Tests/qa/` (68 tests), results in section 6, defects D-1 to D-8 in section 7, slice-0 verdict Fail, TC-59 second-cancel wording corrected. |
| 1.0 | 2026-10-25 | First version (Draft, early mode: no code). 70 API cases (TC-1 to TC-70), 65 iOS cases (TC-101 to TC-165), 67 Android cases (TC-201 to TC-267, of which TC-201 to TC-265 mirror iOS and TC-266, TC-267 are Android-only); all results Not run. Traceability matrix for AC-1 to AC-29. Environment needs E-1 to E-12. Open questions Q-S1 to Q-S14, Q-U1 to Q-U12, Q-A1 to Q-A16, Q-P1 to Q-P4. |
