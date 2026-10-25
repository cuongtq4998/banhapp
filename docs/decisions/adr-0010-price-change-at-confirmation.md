# ADR-0010: Price change between review and confirmation

| Field    | Value |
| -------- | ----- |
| ADR      | 0010 |
| Status   | Proposed (pending owner choice; escalated: changes visible business behaviour) |
| Date     | 2026-10-25 |
| Decider  | Product owner (recommendation by atlas-architect) |
| Based on | PRD BR-5, BR-6, AC-14, AC-23; UI TQ-4 and key `MSG_PRICE_CHANGED` |

## Context

BR-5 says prices are those shown at review. BR-6 says an order keeps the prices shown to the customer at confirmation. The confirmation screen shows no total. A price (or the district fee) may change in the moments between review and the server receiving the confirmation, once the owner can edit prices (later slice; until then only by data update).

## Decision Drivers

- The customer must not pay or be quoted a total they did not see.
- The shop must not be forced to honour an outdated price after a correction.
- Simplicity.

## Options Considered

| Option | Behaviour | Pros | Cons |
| ------ | --------- | ---- | ---- |
| A. Reject and re-review | The client sends the total it showed (`expected_total_vnd`). If the server total differs, the server answers 409 `PRICE_CHANGED` with the new prices and total. S-8 shows the updated review and the message `MSG_PRICE_CHANGED`; the customer confirms again | The customer always agrees to the exact total; no surprise; matches BR-5 literally | One extra tap in a rare case; needs one message and a refreshed review |
| B. Accept at the reviewed price | The server stores the prices the client saw | No friction; honours BR-6 for the customer | The client would send prices (breaks the rule that clients never send computed values); the shop may sell at an outdated price; abuse by keeping a stale review open |
| C. Accept at the current price silently | The server stores current prices | Simple | The customer is quoted a different total than shown; violates BR-5 |

## Decision (recommended: option A)

Option A. The request carries `expected_total_vnd` (the total shown on the review); it is an acknowledgement, not a value the server trusts. On mismatch the response is 409 `PRICE_CHANGED` carrying the current `items` (price per product), `delivery_fee_vnd` and `total_vnd`; no order and no capacity change is made. The order stores the server's prices at the moment of acceptance, which equal the prices the customer last saw (BR-6, AC-23). Written into api.md and order-lifecycle.md against this option. Until the owner decides, the UI copy `MSG_PRICE_CHANGED` stays as proposed (Vietnamese: "Giá đã thay đổi. Vui lòng xem lại đơn hàng.").

## Consequences

- Positive: no hidden price differences; testable (change a price in the database between review and confirm).
- Negative: rare extra step; the client must refresh the catalog from the 409 body.
- Follow-up: canvas-ui confirms behaviour of S-8 on 409 (banner, updated rows, confirm enabled). If the owner picks B or C, `expected_total_vnd` is removed and `PRICE_CHANGED` disappears (a breaking change avoided only if decided before release).

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Business rules BR-5, BR-6 | docs/product/place-order.md v1.2 | 2026-10-25 | High |
| Common e-commerce practice to re-confirm on price change | Architect experience; not researched | 2026-10-25 | Unverified |

## Links

Related: ADR-0008.
