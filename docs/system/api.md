# API Specification

| Field        | Value |
| ------------ | ----- |
| Version      | 1.25 [v1.25 | 2026-11-02] |
| Last updated | 2026-10-31 |
| Status       | Draft |
| Owner        | atlas-architect |
| Based on     | product/place-order.md v1.2; design/place-order-ui.md v1.0; data-model.md v1.0; product/admin-orders.md v1.6 (27 FR, 14 BR) [v1.16 | 2026-10-31] |
| Related      | order-lifecycle.md; admin-order-handling.md; session-lifecycle.md; auth.md; ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0014, ADR-0017, ADR-0019, ADR-0022 to ADR-0031 |

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
| 9, endpoint index (admin), 10.1 to 10.5 | Admin conventions, sign-in, refresh [v1.16 \| 2026-10-31] | [api/05-admin-conventions-auth.md](api/05-admin-conventions-auth.md) |
| 10.6 to 10.12 | Session, sign out other phones, push token, order list, detail, status change, push payload [v1.16 \| 2026-10-31] | [api/06-admin-orders-devices.md](api/06-admin-orders-devices.md) |
| 10.13 to 10.19 | Owner settings, ordering rules, districts, slots, cakes, staff [v1.16 \| 2026-10-31] | [api/07-owner-settings-cakes-staff.md](api/07-owner-settings-cakes-staff.md) |
| 10.13 | Order process of six steps, expected delivery date (today to +7), final fee and its correction [v1.25 \| 2026-11-02] | [api/09-order-process-api.md](api/09-order-process-api.md) |
| 10.14 | Customer order lookup by phone [v1.25 \| 2026-11-02] | [api/10-customer-order-lookup.md](api/10-customer-order-lookup.md) |
| 11 to 13 | Admin error catalogue, compatibility, traceability [v1.13 \| 2026-10-31] | [api/08-admin-errors-compatibility.md](api/08-admin-errors-compatibility.md) |
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
| 1.11 | 2026-10-28 | Clarification only (ADR-0008 v1.1): key lifecycle and replay order in `POST /v1/orders`. No contract change. |
| 1.13 | 2026-10-31 | admin-orders: new files 05 to 08 (sign-in by e-mail code, refresh, recovery, devices, push token, orders list/detail/status, owner settings, cakes with image upload, staff, backup e-mail; error codes). Prefixes `/v1/auth`, `/v1/admin`, `/v1/owner`; `/v1/staff` released. Place Order: per-phone limit ignores cancelled orders except `fake_spam` (api/03 step 7); catalog may list up to 12 cakes (api/02); uploaded images at `/assets/cakes/{id}`. |
| 1.12 | 2026-10-29 | Resync with built slice 3: field-level `VALIDATION_FAILED` codes, paths and order (api/04 section 5); per-address limit counts replays; per-phone limit built (any status, 24 h, check-then-insert, `Retry-After` 3600); `X-App-Version` `N.N.N`; rule "items at most active products" removed; sorted JSON keys; transaction inside the repository. |
| 1.14 | 2026-10-31 | Owner decisions and technical answers: one image route with its own exact body limit (5,308,416 bytes), per-client-address limits on all `/v1/auth` routes, device name format, ordering save returns `over_limit`, last write wins for settings, list paging consistency, offline sign-out, push delivery settings pointer. No new endpoint. |
| 1.15 | 2026-10-31 | PRD v1.4: `CODE_LOCKED` removed (no address lock, a void code answers `CODE_EXPIRED`), recovery counted separately, new-device notice after sign-in; order list gains `view=unfinished` and `unfinished_count`; old unfinished orders reachable for detail and status change. No new endpoint. |
| 1.16 | 2026-10-31 | PRD v1.6 simplification (27 FR, 14 BR). Removed: recovery endpoints, backup e-mail endpoints, device list and revoke, `DELETE /v1/admin/push-token`, `view=unfinished`, `date_from`, `date_to`, repeated `status`, response fields `new_count`, `server_time`, `has_backup_email`, `offer_device_list`, `order_window_days`, detail `history`, error `DEVICE_NOT_FOUND`, cancel reason `day_full`. Added: `DELETE /v1/admin/sessions/others`, list parameter `delivery_date`, status value `todo`, detail field `last_change`. One window rule: open orders of any age, finished orders 90 days (ADR-0029 v1.3). FR and BR ids of the admin files follow PRD v1.6. |
| 1.17 | 2026-11-01 | Aligned with built slice B1: sign-in off (503) when not configured; field codes `EMAIL_INVALID`, `CODE_FORMAT`, `INSTALLATION_ID_INVALID`, `DEVICE_NAME_INVALID`; `device_id` upper-case vs lower-case in tokens; malformed or unknown refresh token is `SESSION_REVOKED`; grace anchored to the first rotation; `Retry-After` at most 3600; 240 and 401 limits dropped; push-token deferred; replay of a close beyond the window answers 200 (R-1). |
| 1.18 | 2026-11-01 | Aligned with built slices B2 and B3 (architecture/11): `q` is 3 to 50 characters (was 2), opaque cursor and `CURSOR_INVALID`, field codes of the list and status change in api/08 section 11.1, status body field codes, items order, open defect D-1 (replay after the window). |
| 1.19 | 2026-11-01 | Aligned with built slices B4 and B5 (architecture/12): staff list body, review accounts hidden, ordering `GET` without `over_limit`, field codes `BODY_EMPTY`, `FIELD_UNKNOWN`, `NAME_TAKEN` (districts), slot time codes, no-op staff `PATCH`, slot renumbering. |
| 1.20 | 2026-11-01 | Aligned with built slice B6 (architecture/13): cake create error table (image codes and keys, `IMAGE_INVALID`, two 413 codes, 503 gate, repeated field `<FIELD>_INVALID`), `GET /assets/cakes/{id}` delivery, cakes list filter, `PATCH` rules; api/06 replay beyond the window now built (D-1). |
| 1.21 | 2026-11-01 | Aligned with built slice B7 (architecture/14): 10.8 push token built (field codes `PLATFORM_MISMATCH`, `PLATFORM_INVALID`, `TOKEN_INVALID`, `APNS_ENVIRONMENT_INVALID`, `UNKNOWN_FIELD`); 10.12 FCM field path `android.notification.title_loc_key`; payload content. |
| 1.22 | 2026-11-01 | `GET /v1/admin/me` also returns the caller's own `email` (own address only, never logged, `no-store`): api/05 index row, api/06 10.6; fixture `admin/me.json` and the backend to follow (architecture/15). |
| 1.23 | 2026-11-01 | Review account and log redaction as built (architecture/16): api/05 section 9 logging row; api/06 10.11 cancel: 500 `INTERNAL_ERROR` with `details.reason = DAY_LOAD_INCONSISTENT`. No new route. |
| 1.24 | 2026-11-02 | Order process of six steps (ADR-0033, api/09 section 10.13): status filter values, badge, detail fields in api/06 10.9 and 10.10, new field codes in api/08 11.1; `order_event` history keeps legacy words, mapped on read. |
| 1.25 | 2026-11-02 | Date range today to +7, fee correction `PUT .../delivery-fee` (api/09 10.13.6, ADR-0033 v1.2); customer lookup `POST /v1/orders/lookup` by phone only with rate limits and minimum data (api/10 section 10.14, ADR-0034). |
