# API Specification

| Field        | Value |
| ------------ | ----- |
| Version      | 1.10 |
| Last updated | 2026-10-27 |
| Status       | Draft |
| Owner        | atlas-architect |
| Based on     | product/place-order.md v1.2; design/place-order-ui.md v1.0; data-model.md v1.0 |
| Related      | order-lifecycle.md; auth.md; ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0014, ADR-0017, ADR-0019 |

Decided: ADR-0010 is Accepted by the owner: option A, reject with `PRICE_CHANGED` and let the customer re-review (`expected_total_vnd` stays). [v1.1 | 2026-10-25] Backend framework is Vapor (ADR-0001); the conventions below are implemented as Vapor middleware. [v1.1 | 2026-10-25]

This file is the index of the API specification. The body lives in the folder `api/`, split by topic so that no file passes 200 lines (CLAUDE.md "Project rule: file size"). Section numbers are unchanged: "api.md section 4.3" still means the same text, found through the map below. [v1.10 | 2026-10-27]

## Section map [v1.10 | 2026-10-27]

| Section | Subject | File |
| ------- | ------- | ---- |
| 1 | Conventions: base path, headers, rate limits, error format | [api/01-conventions-and-index.md](api/01-conventions-and-index.md) |
| 2 | Endpoint index (FR and BR traced) | [api/01-conventions-and-index.md](api/01-conventions-and-index.md) |
| 3 | Shared schemas | [api/01-conventions-and-index.md](api/01-conventions-and-index.md) |
| 4.1, 4.2 | `GET /v1/catalog`, `GET /v1/availability` | [api/02-catalog-availability.md](api/02-catalog-availability.md) |
| 4.3 | `POST /v1/orders` | [api/03-orders.md](api/03-orders.md) |
| 4.4, 4.5, 4.6 | `GET /healthz`, `GET /privacy`, `GET /assets/*` | [api/04-ops-endpoints-errors-compatibility.md](api/04-ops-endpoints-errors-compatibility.md) |
| 5 | Error catalogue | [api/04-ops-endpoints-errors-compatibility.md](api/04-ops-endpoints-errors-compatibility.md) |
| 6, 7 | Compatibility policy, traceability check | [api/04-ops-endpoints-errors-compatibility.md](api/04-ops-endpoints-errors-compatibility.md) |
| 8 | Open questions and change log | this file |

## 8. Open Questions / Change log

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| API-Q1 | Message keys for `PRODUCT_UNAVAILABLE`, `SLOT_UNAVAILABLE`, `RATE_LIMITED` | Client text by code | No | technical | Closed 2026-10-26: UI document v1.1 defines all three; table in section 5 lists the key per code | atlas-architect |
| API-Q2 | Price-change behaviour (ADR-0010) | `expected_total_vnd`, `PRICE_CHANGED` | No | business | Closed: owner accepted option A (2026-10-25) | Owner |

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version. |
| 1.1 | 2026-10-25 | ADR-0010 accepted; Vapor implementation notes; shallow and deep health check; trial-host timeout note. |
| 1.2 | 2026-10-26 | Health check consumers clarified (shallow for monitors, deep for operator and deploy checks). |
| 1.3 | 2026-10-26 | Error catalogue: top-level `message_key` per code, `NOT_FOUND` and `METHOD_NOT_ALLOWED`, `RATE_LIMITED` key and `Retry-After`, framework error mapping, database outage wrapping rule; API-Q1 closed. |
| 1.4 | 2026-10-26 | Body limit boundary stated (8 KB passes, one byte more fails); `Retry-After` default 60 s. |
| 1.5 | 2026-10-26 | D-9: unrouted method and path pair answers 404 `NOT_FOUND`; 405 kept only when raised by the framework or a handler. |
| 1.6 | 2026-10-26 | QA document findings (DOC-1 to DOC-7, DOC-10) and owner decision on the catalog: every active cake is listed (zero active is the only error case); one image field rule and asset versioning; strong ETag with weak `If-None-Match` comparison; one shared read budget with `Retry-After` rule; unknown query parameters ignored; `note_max_length` is a constant; sample wording removed from examples. ADR-0017. |
| 1.7 | 2026-10-26 | DOC-11: `HEAD` answers like `GET` and counts; D-18: per-address window, 10,000-address bound, only `GET`/`HEAD` counted, 429 not counted; D-20: ETag wording; client address rule with one proxy. |
| 1.8 | 2026-10-26 | UI TQ-9, TQ-10: `PRODUCT_UNAVAILABLE` `details.product_ids`, nothing stored; catalog refresh counted against the read budget (ADR-0011). |
| 1.9 | 2026-10-27 | Slice 2 gaps: `cakes` field error confirmed (`CAKES_INVALID`, `ERR_SERVER`), zero active products makes every `cakes` a 422, error responses carry no cache header except 404 (RFC 9110 15.1), field-level codes and the repository error name noted. Client address rule points to ADR-0019. (Version 1.8 above was UI TQ-9 and TQ-10.) |
| 1.10 | 2026-10-27 | Split into the folder `api/` (file size rule, 200 lines); this file became the index with a section map. No contract change. The naming note in section 5 now points to the `DomainError` rule of ADR-0018. |
