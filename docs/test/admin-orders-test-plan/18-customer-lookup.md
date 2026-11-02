# Admin Orders Test Plan: Customer Order Lookup API (part 18)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.2). Section 4.31 (new in v2.2 [v2.2 | 2026-11-02]) for place-order FR-22 to FR-27, BR-15 to BR-18, AC-38 to AC-48, Admin Orders FR-28 to FR-30, api/10 v1.0, ADR-0034. Early mode: all `Not run`. Fake phones only (+84900000000 to +84900000099). Security tests are black-box (HTTP only plus logs and DB read for evidence) and negative first. Levels: API contract, API+DB. Endpoint POST `/v1/orders/lookup`.

## 4.31 Lookup tests

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B601 | negative | API | api/10 10.14.1 | GET, PUT, DELETE, PATCH, HEAD, OPTIONS on the route; phone in query string | 405 or 404 per api/04; never an order; a phone in a URL is never read |
| TC-B602 | negative | API | 10.14.6 | Phone missing, null, "", "abc", "+8490000000" (short), "+849000000012345", 0900000001 with letters, number, array | 422 `VALIDATION_FAILED` `PHONE_REQUIRED` or `PHONE_INVALID`; same shape for all; no DB query run (limiter first) |
| TC-B603 | negative | API | 10.14.6 | Unknown field in body ("order_code", "name"), empty body, invalid JSON, body 8 KB or more | `FIELD_UNKNOWN`; 422 for bad JSON; 413 `PAYLOAD_TOO_LARGE` |
| TC-B604 | acceptance | API+DB | AC-44, AC-45 | Phone with orders placed 08/11 and 10/11 | 200; 10/11 order first; field set exactly as in api/10 10.14.1 |
| TC-B605 | acceptance | API | 10.14.1 | Phone forms "0900000001", "+84 900 000 001", "0900.000.001", " 0900000001 " | All normalise to one number; same orders returned |
| TC-B606 | negative | API | BR-16, 10.14.2 | Deep field check of every answer (open, cancelled, finished, corrected, empty): compare the key set with the allow-list recursively | No key outside the list; none of: street, ward, note, customer name, `cancel_reason`, staff or account names or ids, `day_load`, `id`, event rows, `date_changes`, `fee_corrections`, `is_sample`, full phone |
| TC-B607 | negative | API+DB | BR-16, AC-43 | Cancelled order with reason "fake or spam order", also a long reason | Answer has status and listed fields only; reason text absent from body and headers (string search) |
| TC-B608 | negative | API+DB | AC-47 | Seed unique marker strings in address, note, name, staff name, reason; look up | None of the markers appears anywhere in the response text |
| TC-B609 | acceptance | API | AC-47 | Masking: "+84 900 000 ***", last 3 digits only; different phones; phone with fewer groups | Never more than the input's own digits minus last 3; address field holds district name only |
| TC-B610 | extra | API | 10.14.1 | Legacy words in DB rows (New, Confirmed, Completed) via fixture | Status sent is one of the six names; legacy never sent |
| TC-B611 | acceptance | API+DB | AC-40, AC-41 | Fee null, 25 000, then corrected to 30 000 | Null before entry (`delivery_fee_final_vnd`, `amount_to_collect_vnd` null); after correction only 30 000 and 270 000; 25 000 nowhere in the body |
| TC-B612 | acceptance | API+DB | AC-39 | Expected date null, set, moved | `expected_delivery_date` null then latest value; requested date stays |
| TC-B613 | negative | API | AC-48 | Phone with orders vs phone without orders vs unused valid phone vs purged phone | Empty cases: 200 `{orders:[],next_cursor:null,as_of}`, same header names and key order; identical for the three empty cases |
| TC-B614 | extra | API | 10.14.4 | Timing: 200 requests per class (with orders, none), compare median and spread | Both at least `LOOKUP_MIN_RESPONSE_MS` (250); medians differ by under 10 percent and 30 ms; the DB query cost is not visible. Record as measurement, not a hard gate on CI |
| TC-B615 | extra | API | 10.14.4 | Response time with an artificially slow query (above 250 ms) for the non-empty case | Documented residual: slower non-empty answer; record the delta, no pass or fail |
| TC-B616 | acceptance | API+DB | 10.14.3 | 12 orders for one phone | Page 1: 10 and cursor; page 2: 2 and null; order `placed_at` desc then `id`; no duplicate or gap |
| TC-B617 | boundary | API+DB | 10.14.3 | 60 orders | Pages of 10, page 5 has `next_cursor` null; at most 50 orders; the 51st never reachable |
| TC-B618 | boundary | API+DB | 10.14.3 | Orders with equal `placed_at` across a page border | Tie broken by `id`; none repeated or lost |
| TC-B619 | negative | API | 10.14.3 | Cursor from phone A used with phone B | 422 `CURSOR_INVALID`; no orders of A or B returned |
| TC-B620 | negative | API | 10.14.3 | Cursor malformed, truncated, one byte changed, empty string, huge, from another environment key | 422 `CURSOR_INVALID` each; never 500; no stack text |
| TC-B621 | extra | API+DB | 10.14.3 | Order added or finished between page 1 and 2 | No crash; no duplicate; stated that a new order can shift nothing (cursor is by time) |
| TC-B622 | boundary | API+DB | BR-18, AC-47 | Window: Finished 29, 30, 31 days ago; Cancelled the same; open order 90 days old; clock control | 29 and 30 shown (per 30-day rule, confirm edge day), 31 not; open any age shown; Finished 31 days not "found" either |
| TC-B623 | extra | API+DB | 10.14.3 | `LOOKUP_RETENTION_DAYS` changed in configuration; row with purged phone | New value honoured; purged row never matches |
| TC-B624 | acceptance | API | 10.14.5 | 11th lookup within an hour for one phone (empty or not; page 2 counts) | 429 `RATE_LIMITED`, `Retry-After` whole seconds 1 to 3600; the first 10 are 200 |
| TC-B625 | acceptance | API | 10.14.5 | 31st lookup from one address with different phones | 429 identical in shape to TC-B624 |
| TC-B626 | acceptance | API | 10.14.5 | 21st lookup with the same `X-Installation-Id` (other phones, other addresses) | 429; and a changed or omitted id is not limited by this key (cosmetic) |
| TC-B627 | negative | API | 10.14.5 | Compare 429 bodies and headers from phone key, address key, installation key; phone with and without orders | Byte-identical body; same header names; `Retry-After` only differs in value; the body does not say which key |
| TC-B628 | extra | API | 10.14.5 | 429 does not count; window reset after the hour (clock control); limits before DB (no query on 429) | Counter unchanged after 429; resets at window end; zero DB queries on 429 |
| TC-B629 | extra | API | 10.14.5 | Invalid phone requests: do they count? | Record the real behaviour; invalid phone must not create counters keyed on garbage (memory) |
| TC-B630 | negative | API | ADR-0034 | Enumeration: sweep 100 numbers sequentially from one address | 429 after the address limit; nothing in the answers separates numbers with orders except the list itself; no 404, no 401, no different status |
| TC-B631 | negative | API | ADR-0034 | Enumeration from a distributed source (rotating `X-Forwarded-For`, omitted id) | Forged forwarded headers do not create new buckets unless the proxy model of ADR-0019 trusts them; record which |
| TC-B632 | extra | API | ADR-0034 | Attacker uses up a victim phone's 10 per hour; the victim then looks up | Victim gets 429 (documented residual risk, accepted); no data leak while blocked; recovers after the window; record as accepted, not as a defect |
| TC-B633 | negative | API | 10.14.7 | Response headers | `Cache-Control: no-store`, `Content-Type: application/json`, no `ETag`, no `Last-Modified`, no `Set-Cookie`, same on 200, 422, 429 |
| TC-B634 | negative | API+DB | 10.14.7 | Log privacy: run lookups with unique marker phone, cursor, installation id; capture stdout, stderr and the log file; search for the phone in every form (+84, 0, spaces, last 3 digits groups), cursor text, installation id, order codes, body | No match. Logs hold only method, route template, status, duration, limiter decision. Run also for 422, 429 and 503 paths and with a crash-style invalid JSON |
| TC-B635 | negative | API+DB | 10.14.7 | Same check on the database side: no phone in limiter structures or `pg_stat_statements` text; keys are keyed hashes | No raw digits in memory dump of limiter keys (unit probe) or logs; hash differs with another `LOOKUP_KEY_SECRET` |
| TC-B636 | extra | API | 10.14.6 | Database down | 503 `SERVICE_UNAVAILABLE` same shape as api/04; no phone echoed |
| TC-B637 | extra | API contract | 10.14.8 | Fixtures `order-lookup-request.json`, answers (open, cancelled, empty) and the three error fixtures decode and match live bodies | Fixture phones in range only; shapes identical |
| TC-B638 | extra | API | 10.14.1 | Replay of POST with the same body and `Idempotency-Key` header | Read-only; no side effect; counts against the limit each time |
| TC-B639 | extra | API | 10.14.1 | Phone with 1 order, many items; unicode cake names; zero fee estimate not allowed | Arrays complete; text encoded as UTF-8; amounts equal items sum plus fee |
