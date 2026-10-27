# Data Model

| Field        | Value |
| ------------ | ----- |
| Version      | 1.4 |
| Last updated | 2026-10-27 |
| Status       | Draft |
| Owner        | atlas-architect |
| Based on     | product/place-order.md v1.2; design/place-order-ui.md v1.0 |
| Related      | architecture.md; api.md; order-lifecycle.md; ADR-0002, ADR-0008, ADR-0009, ADR-0013, ADR-0017 |

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
