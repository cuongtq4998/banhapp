# ADR-0013: Source of shop configuration and sample data

| Field    | Value |
| -------- | ----- |
| ADR      | 0013 |
| Status   | Accepted |
| Date     | 2026-10-25 |
| Decider  | atlas-architect |
| Based on | PRD Q-T2, section 12.1, AC-29; BR-1 to BR-4, BR-8, BR-10 |

## Context

Products, prices, districts, fees, slots, daily limit, lead days, minimum quantity, horizon and shop contact data are shop parameters. The owner configuration UI is a later slice. AC-29 requires sample values, marked as sample in the data source, and no visible marker in the app.

## Decision Drivers

- The later owner slice must take over without changing this slice's API.
- No parameter value is hard-coded in code or in the requirements.
- Sample data is clearly fake and never mistaken for real data.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Database tables, filled by a seed script now, edited by the owner API later | Same read path now and later; constraints apply; `shop_id` ready | Until the owner slice exists, changes need a script run |
| B. Config file or environment variables read at start | Quick | Requires redeploy per change; later migration to tables; not queryable for constraints |
| C. Bundle values in the apps | No server read | Violates "configuration, not fixed values"; stale |

## Decision

Option A. Tables `shop`, `shop_setting`, `product`, `district`, `delivery_slot` (data-model.md). Every row of these tables has `is_sample boolean`; the seed file `backend/db/seed/sample.sql` inserts fake values with `is_sample = true` (the apps never read or show this flag; the API does not expose it). The shop's real values are applied by a reviewed seed or SQL change that sets `is_sample = false`; a startup check logs a warning (not an error) when `APP_ENV=production` and any row still has `is_sample = true`. The later owner slice replaces the seed script by authenticated write endpoints on the same tables. All order rules read these tables at request time; there are no rule constants in code except the input-safety bounds in ADR-0009 (including the note length 200 returned as `settings.note_max_length`, ADR-0017). Seed text that can reach a screen carries no sample marker [v1.1 | 2026-10-26].

## Consequences

- Positive: no API change when owner configuration arrives; sample data cannot be confused with real data in the database.
- Negative: before the owner slice, a change of price or limit needs a developer to run SQL (documented in deployment.md section 4).
- Follow-up: launch checklist item "no sample rows in production" (deployment.md).

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Requirements and acceptance criteria | docs/product/place-order.md v1.2 | 2026-10-25 | High |

## Links

Related: ADR-0002, ADR-0010.
