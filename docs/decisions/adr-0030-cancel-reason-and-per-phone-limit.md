# ADR-0030: Cancel reason storage and the per-phone limit rule

| Field    | Value |
| -------- | ----- |
| ADR      | 0030 |
| Version  | 1.2 [v1.2 | 2026-11-01] (built in slice B3; file name and capacity text corrected; earlier: four reasons, PRD v1.6 BR-8) |
| Status   | Accepted (implements the owner decisions Q-9 and Q-12; no money) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD admin-orders v1.6 FR-18, FR-14, FR-27, BR-3, BR-8, AC-28, AC-46 (ids as in product/admin-orders/08, section 15); TQ-8; ADR-0014 |

## Context

A cancellation needs one of four reasons ("day full" and "cannot deliver" were merged, P-4) [v1.1 | 2026-10-31]. A cancelled order stops counting toward the limit of 5 orders per phone per 24 hours, except one cancelled as "fake or spam order". The rule of slice 3 counted orders of any status; slice B3 changed it as described below [v1.2 | 2026-11-01].

## Decision Drivers

- The rule must hold for direct SQL too (standard 04 rule 4).
- The history must show the reason and cannot be edited.
- The count query stays on the existing index.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Column `cancel_reason` on `customer_order` with a CHECK, copied into `order_event.reason` by the trigger (chosen) | The count query needs no join; the audit row keeps the reason; one write | Two places hold the value (the event is the record, the column the working copy) |
| B. Reason only in `order_event`, joined in the count | Single copy | Join in the hot per-phone check |
| C. Separate cancellation table | Normalised | Extra table and join for four fixed values |

## Decision

Option A. Values [v1.1 | 2026-10-31]: `customer_asked`, `cannot_deliver` (also when the day is full), `cannot_reach_customer`, `fake_spam`. The value `day_full` of v1.0 is removed; it was never stored in a built database (migration 0003 is built since slice B2 and B3 [v1.2 | 2026-11-01]). CHECK: `(status = 'Cancelled') = (cancel_reason IS NOT NULL)`. The reason cannot change after it is set (extended `customer_order_immutable` trigger). `customer_order_release_capacity` copies `NEW.cancel_reason` and the actor name (`app.actor_name`) into the event. Existing `Cancelled` rows would violate the CHECK: the migration stops with an error if any exist (none expected; the cancel path was never exposed).

Per-phone rule: the count counts a stored order when `status <> 'Cancelled' OR cancel_reason = 'fake_spam'`, with the 24-hour window measured on the order's `created_at` (unchanged). Files and text to change in Place Order:

| File | Change |
| ---- | ------ |
| `backend/Sources/App/Repositories/PostgresOrderRepository.swift` (`countOrders`, line 45) | Add `AND (status <> 'Cancelled' OR cancel_reason = 'fake_spam')` to the SQL |
| `backend/Sources/App/Repositories/OrderRepository.swift` (protocol doc) and `Services/OrderPlacementService.swift` (call at line 50) | Comment and naming only: "counted orders" instead of "orders of any status" |
| `backend/Tests/**` order-limit tests and fixtures | New cases AC-46; the old "cancelled orders count" test changes |
| `backend/db/migrations/0003_admin_orders.sql` (the cake and settings part of the planned `_catalog` file waits for its slice) | New column, CHECK, triggers, indexes, `search_fold` [v1.2 | 2026-11-01] |
| `docs/system/api/03-orders.md` step 7 and `docs/system/api.md`/`api/01` rate-limit row | Wording: counted orders; done in this version |
| `docs/system/auth.md` section 4 (customer abuse table) and `docs/system/data-model/02-orders-and-events.md` text on the per-phone count | Done in this version |
| `docs/decisions/adr-0014-abuse-protection.md` | Amendment v1.3, done |
| `docs/product/place-order.md` and its parts (BR/AC that state the limit, Q-O3) | Owned by scribe-requirements: query below |

## Consequences

- Positive: rule enforced next to the data; history shows reasons; the per-phone check keeps its index.
- Negative: the count now depends on `cancel_reason`; a fake order cancelled with another reason frees the phone (accepted by the owner, Q-12).
- Follow-up: query to scribe-requirements to update Place Order BR-7 area, its ACs and Q-O3 wording.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Current code and index | `backend/Sources/App/Repositories/PostgresOrderRepository.swift`, `backend/db/migrations/0001_init.sql` | 2026-10-31 | High |

## Links

Amends ADR-0014 (count rule). Related: ADR-0028. Detail: data-model/05.

## Amendment v1.2 [v1.2 | 2026-11-01]: as built

- Built in `PostgresOrderRepository.countOrders`: `created_at` within 24 hours AND `(status <> 'Cancelled' OR cancel_reason = 'fake_spam')`. An open order counts; cancelling it as `fake_spam` keeps it counting, cancelling it for any other reason removes it from the count; the first reason stays for good (immutable trigger). `POST /v1/orders` (api/03 step 7) and the place-order documents carry the same rule.
- Cancelling returns the cakes: the trigger subtracts `total_cakes` from the `day_load` row of the order's date and does nothing when that row does not exist (an old order whose row is gone). There is no `GREATEST(..., 0)` floor: the column CHECK `cakes_accepted >= 0` is the guard, and a cancellation can only fail on it if the counter was corrupted by hand. A repeated cancel writes nothing, so the cakes return once (ADR-0028).
