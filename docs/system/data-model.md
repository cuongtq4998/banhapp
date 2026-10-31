# Data Model

| Field        | Value |
| ------------ | ----- |
| Version      | 1.6 [v1.6 | 2026-10-31] |
| Last updated | 2026-10-31 |
| Status       | Draft |
| Owner        | atlas-architect |
| Based on     | product/place-order.md v1.2; design/place-order-ui.md v1.0; product/admin-orders.md v1.2 [v1.6 | 2026-10-31] |
| Related      | architecture.md; api.md; order-lifecycle.md; ADR-0002, ADR-0008, ADR-0009, ADR-0013, ADR-0017, ADR-0022, ADR-0025, ADR-0029 to ADR-0031 |

This file is the index of the data model. The body lives in the folder `data-model/`, split by topic so that no file passes 200 lines (CLAUDE.md "Project rule: file size"). Section numbers are unchanged: "data-model.md section 5" still means the same text, found through the map below. [v1.4 | 2026-10-27]

## Section map [v1.4 | 2026-10-27]

| Section | Subject | File |
| ------- | ------- | ---- |
| 1 | Overview and conventions | [data-model/01-overview-and-configuration.md](data-model/01-overview-and-configuration.md) |
| 2 | Entity relationship diagram | [data-model/01-overview-and-configuration.md](data-model/01-overview-and-configuration.md) |
| 3.1 to 3.6 | `shop`, `shop_setting`, `product`, `district`, `delivery_slot`, `day_load` | [data-model/01-overview-and-configuration.md](data-model/01-overview-and-configuration.md) |
| 3.7 to 3.9 | `customer_order`, `customer_order_item`, `order_event` | [data-model/02-orders-and-events.md](data-model/02-orders-and-events.md) |
| 4 | Enumerations | [data-model/02-orders-and-events.md](data-model/02-orders-and-events.md) |
| 5 | Indexes and constraints, triggers | [data-model/03-constraints-rules-migrations.md](data-model/03-constraints-rules-migrations.md) |
| 6 | Data rules | [data-model/03-constraints-rules-migrations.md](data-model/03-constraints-rules-migrations.md) |
| 7 | Sensitive data | [data-model/03-constraints-rules-migrations.md](data-model/03-constraints-rules-migrations.md) |
| 8 | Migrations | [data-model/03-constraints-rules-migrations.md](data-model/03-constraints-rules-migrations.md) |
| 9 | Traceability | [data-model/03-constraints-rules-migrations.md](data-model/03-constraints-rules-migrations.md) |
| 3.10 to 3.16 | `account`, `device_session`, `auth_code`, `auth_email_state`, `push_token`, `security_event`, `settings_change`; sensitive data added [v1.6 \| 2026-10-31] | [data-model/04-admin-accounts-sessions.md](data-model/04-admin-accounts-sessions.md) |
| 11 to 16 | Changes to `customer_order`, `order_event`, `product`, `product_image`, settings CHECKs, `day_load` and the daily limit, purge jobs, migrations `0002` and `0003`, traceability [v1.6 \| 2026-10-31] | [data-model/05-admin-orders-cakes-settings.md](data-model/05-admin-orders-cakes-settings.md) |
| 10 | Open questions and change log | this file |

## 10. Open Questions / Change log

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| DM-Q1 | Retention period of customer contact data (BR-12) | Purge job and privacy text | No | business | Open (owner, already in PRD 12.1) | |
| DM-Q2 | Database choice (ADR-0002) | Schema is written for PostgreSQL | No | technical | Closed: owner accepted PostgreSQL (2026-10-25) | Owner |

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version. |
| 1.1 | 2026-10-25 | PostgreSQL accepted; Swift/Fluent migration mechanics. |
| 1.2 | 2026-10-26 | After slice 0: trigger writes an `order_event` on every status change with a session-settable actor; migration reviewed against the document; `updated_at` is set by the application. |
| 1.3 | 2026-10-26 | QA findings DOC-1, DOC-5, DOC-6, DOC-7: `image_path` rule, products not limited to four, seed wording and fake phone rule, `note_max_length` constant. |
| 1.4 | 2026-10-27 | Split into the folder `data-model/` (file size rule, 200 lines); this file became the index with a section map. No schema change. |
| 1.5 | 2026-10-29 | Slice 3 resync (02 orders): the `created` event and the counter are written by the transaction inside `OrderRepository.insertOrder`; per-phone count reads `customer_order` of any status in the last 24 hours. No schema change. |
| 1.6 | 2026-10-31 | admin-orders: new files 04 and 05. Tables `account`, `device_session`, `auth_code`, `auth_email_state`, `push_token`, `security_event`, `settings_change`, `product_image`; columns `cancel_reason`, `is_demo`, `order_event.reason/actor_name`, `product.removed_at/image_source`; CHECKs and triggers; per-phone count excludes cancelled orders except `fake_spam`; `day_load.capacity_limit` is a copy, not an authority; migrations 0002 and 0003; purge jobs. Answers TQ-5, TQ-7 to TQ-9. |
