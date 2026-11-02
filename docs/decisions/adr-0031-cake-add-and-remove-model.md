# ADR-0031: Adding and removing cakes while keeping order history

| Field    | Value |
| -------- | ----- |
| ADR      | 0031 |
| Version  | 1.1 [v1.1 | 2026-10-31] (traceability ids only) |
| Status   | Accepted (implements Q-6 and Q-17; no money) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD admin-orders v1.6 FR-21, BR-11, BR-12, AC-32, AC-33 (ids as in product/admin-orders/08, section 15); TQ-9; data-model 3.3, 3.8 |

## Context

Removed cakes disappear from the customer app and the settings list but stay in earlier orders with name, quantity and price. `customer_order_item` already snapshots name and price and references `product` with `ON DELETE RESTRICT`. Place Order already treats an inactive product as unavailable.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Soft removal: `product.removed_at`, and `is_active = false` forced by CHECK (chosen) | Foreign keys stay valid; existing catalog and order checks (`is_active`) work unchanged; no data loss | A flag to filter in the admin list |
| B. Hard delete | Clean table | Blocked by the foreign key; history would lose the link |
| C. Archive table | Separate | Copy logic; two sources |

## Decision

Option A. States: active (`is_active`, not removed), hidden (not `is_active`, not removed), removed (`removed_at` set, `is_active` false). Removal is final (no restore). Rules in the database: partial unique index on `(shop_id, lower(name)) WHERE removed_at IS NULL`; a trigger refuses a 13th non-removed cake; slug of new cakes is `cake-<first 8 hex of id>`. Rules in the service under one row lock (`SELECT ... FOR UPDATE` on the `shop_setting` row, so two requests cannot both pass): at least one active cake, district and slot must remain (BR-11); a refusal is `LAST_ACTIVE_CAKE`, `LAST_ACTIVE_DISTRICT`, `LAST_ACTIVE_SLOT`. The database does not enforce "one active" because Place Order treats zero active as a legal error state and its tests create it. Removal deletes the stored image bytes (ADR-0025). Customer queries add `removed_at IS NULL` only for clarity; `is_active` already excludes removed rows.

## Consequences

- Positive: history intact; small change to existing queries.
- Negative: removed rows accumulate (about 12 live; negligible).
- Follow-up: the admin list shows non-removed cakes only; order detail shows the stored `product_name`.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Existing foreign keys and snapshots | `backend/db/migrations/0001_init.sql`, data-model 3.8 | 2026-10-31 | High |

## Links

Related: ADR-0025, ADR-0013.
