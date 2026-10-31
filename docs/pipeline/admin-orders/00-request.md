# Request: Admin Orders

| Field | Value |
| ----- | ----- |
| Slug | admin-orders |
| Type | change (second feature on the existing monorepo) |
| Date | 2026-10-31 |
| Source | Product owner, via the orchestrator; the owner said "go ahead" and left the shape open |

## Description (owner's intent)

Shop staff and the owner receive and handle the orders that customers place with the `place-order` feature. The design reference already contains four admin screens (A1 sign-in, A2 order list, A3 order detail, A4 settings); see `docs/design/reference/screens/{ios,android}-a1..a4-*.html`.

`docs/product/place-order/01-overview.md` lists what was left out of place-order and belongs here: phone OTP sign-in, order list and statuses (New, Confirmed, Completed, Cancelled), owner configuration (products, prices, districts, delivery fees, daily limit, time slots, shop information, staff), and push notifications.

## Open decisions (the requirements author proposes, the owner approves at the requirements gate)

- Whether admin is inside the customer app (role-gated) or a separate app.
- Whether both iOS and Android are needed, or one platform first.

## Constraints

- Reuse the existing backend (Swift/Vapor, PostgreSQL) and the order data model from `place-order`.
- The repository is public: no real data, hosts or secrets.

## Existing docs

`docs/product/place-order.md`, `docs/product/place-order/`, `docs/system/`, `docs/design/`, `docs/decisions/`.
