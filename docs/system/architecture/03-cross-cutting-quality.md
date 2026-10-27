# System Architecture: Cross-cutting concerns, quality, constraints, extension points

Part of [architecture.md](../architecture.md) (index, version, change log), sections 7 to 10. Moved from architecture.md v1.7 with the wording unchanged unless a line carries a newer label [v1.8 | 2026-10-27].

## 7. Cross-cutting Concerns

- Security and customer data: HTTPS only; no accounts; server computes all money; rate limits; personal data only in the order table and the device draft; no personal data in logs (auth.md, data-model.md section 7).
- Observability: structured JSON logs with a request id, `/healthz`, uptime check and alerts (deployment.md section 7).
- Error handling: machine-readable error codes mapped to Vietnamese message keys by the apps (api.md section 5). Entered data is never lost on error (FR-17).
- Configuration: all shop parameters in database tables (ADR-0013); runtime settings in environment variables (deployment.md section 3).
- Localization: Vietnamese only; strings in resource files keyed as in the UI document; server sends keys, not text (FR-14).
- Time: Vietnam time (UTC+7) for all business dates; the server date is authoritative (A-1).
- Accessibility and look: native components, `material.fallback` rules (ADR-0012, design-system.md).
- Privacy: privacy page `/privacy`; the apps state what is collected before confirmation (PRD section 8); store privacy forms in deployment.md section 4.

## 8. Quality Attributes

| Attribute | Target | Basis |
| --------- | ------ | ----- |
| Order submission result | At most 10 s from tap to confirmation or error (client timeout 10 s) | PRD section 8 |
| `POST /v1/orders` server time | p95 at most 1 s with a warm server and database; after a database resume at most 5 s; after a server sleep up to about 60 s on the free trial host (not met; the apps cope by retrying with the same key, ADR-0003) [v1.1 | 2026-10-25] | Estimate; resume time from Neon docs, server wake from Render docs |
| `GET /v1/catalog`, `GET /v1/availability` server time | p95 at most 500 ms | Estimate |
| Availability of the API | 99.5% per month on the paid path (about 3.6 hours of downtime); the free trial has no target [v1.1 | 2026-10-25] | Single instance, estimate |
| Expected load | Up to 100 orders per day, up to 2,000 app opens per day, peak 5 requests per second | Small shop assumption, unverified; design margin ten times |
| Correctness | 0 orders accepted beyond the daily limit, under 50 parallel requests in test | G-2, AC-22 |
| Data durability | Backup every 24 hours (recovery point 24 h); restore within 4 hours (recovery time) | deployment.md section 6 |
| Cost | USD 0 during the trial; about USD 7 to 27 per month on the paid always-on path (estimate) [v1.1 | 2026-10-25] | ADR-0003 |
| Accessibility | WCAG 2.2 AA contrast 4.5:1; dynamic type | PRD section 8 |

## 9. Constraints & Assumptions

- Public repository: placeholders and fake data only (00-common.md).
- One shop at launch (`shop_id` ready for more).
- Payment is outside the app; the API has no payment data (FR-19).
- Order handling by the shop is outside this slice; staff read orders via the database or later via the staff slice.
- Assumed: shop timezone UTC+7 with no daylight saving time (A-1).
- Assumed: the free Neon and Render terms stay as researched on 2026-10-25 (ADR-0003, unverified over time). No spend during the new-project phase (owner). [v1.1 | 2026-10-25]

## 10. Extension Points for Later Slices

| Later feature | Prepared by |
| ------------- | ----------- |
| Staff and owner login | Reserved `/v1/staff` prefix; `order_event.actor_type/actor_id`; auth.md placeholder |
| Order list and statuses New, Confirmed, Completed, Cancelled | `customer_order.status`, transition trigger, indexes by shop and status |
| Owner configuration of products, prices, districts, fees, limit, slots, shop info | Tables in data-model.md read at request time; `is_active`, `sort_order`; the same read path |
| Payment | `customer_order.payment_status` placeholder, not exposed |
| Push notifications | Not prepared beyond staff identity; needs a new ADR |
| More shops | `shop_id` on every table |
