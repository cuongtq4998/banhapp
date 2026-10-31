# API Specification: Owner settings, cakes, staff, backup e-mail

Part of [api.md](../api.md) (index, version, change log), sections 10.13 to 10.19. New in v1.13 [v1.13 | 2026-10-31]. All routes under `/v1/owner`: role owner only (staff get 403 `FORBIDDEN`, AC-12). Every successful write is one transaction that also writes `settings_change` rows (FR-30) and changes nothing on refusal (FR-28). Validation errors list every problem in `fields[]` with codes `*_REQUIRED`, `*_INVALID`, `*_TOO_LONG`, `*_OUT_OF_RANGE` and message keys `ERR_FIELD_*`. Limits are those of BR-9 and BR-18. Changes apply to new orders only (FR-29, BR-21).

### 10.13 GET /v1/owner/settings

200: `shop` (`name`, `greeting`, `phone_contact`, `zalo_contact`), `ordering` (`daily_limit`, `lead_days`, `min_qty`, fixed `max_days_ahead`), `cakes` (non-removed: `cake_id`, `name`, `description`, `price_vnd`, `is_active`, `image_url`), `districts` (`district_id`, `name`, `delivery_fee_vnd`, `is_active`), `slots` (`slot_id`, `start`, `end`, `is_active`, sorted), `cake_count_max: 12`, `staff_count_max: 30`. Staff cannot call it.

### 10.14 PUT /v1/owner/settings/shop

Body: `name` (1 to 100), `greeting` (1 to 300), `phone_contact` (E.164 as data-model 3.1), `zalo_contact` (3 to 100). All required (BR-9). 200 returns the section. Errors: 422 `VALIDATION_FAILED`.

### 10.15 Ordering rules

`PUT /v1/owner/settings/ordering` body `daily_limit` (1 to 9999), `lead_days` (0 to 14), `min_qty` (1 to 20 and at most `daily_limit`); all required; 200 returns the section. Lowering the limit below accepted cakes cancels nothing (BR-10, data-model/05). `GET /v1/owner/settings/ordering/impact?daily_limit=60` returns `{ "daily_limit": 60, "over_limit": [ { "date": "2026-11-05", "cakes_accepted": 98 } ], "count": 1 }` for dates from the server date on (AC-38); it writes nothing. The customer catalog `settings` object already carries `min_qty` and `lead_days` (api/02), so customer apps show current values after their next refresh (FR-40).

### 10.16 Districts and slots

`POST /v1/owner/districts` body `name` (1 to 100, unique), `delivery_fee_vnd` (1 to 10,000,000); 201 returns the district. `PATCH /v1/owner/districts/{id}` any of `name`, `delivery_fee_vnd`, `is_active`; 200. Deactivating the last active district: 409 `LAST_ACTIVE_DISTRICT`. Slots: `POST /v1/owner/slots` body `start`, `end` (`HH:MM`, `start < end`, no existing slot with the same pair, 422 `SLOT_DUPLICATE`); `PATCH /v1/owner/slots/{id}` any of `start`, `end`, `is_active`; last active: 409 `LAST_ACTIVE_SLOT`. Unknown id: 404 `NOT_FOUND`. Earlier orders keep their snapshot of name, fee and slot (AC-35, AC-36, AC-39, AC-40, AC-46).

### 10.17 Cakes

`POST /v1/owner/cakes` is `multipart/form-data` with text fields `name` (1 to 100, unique among non-removed, case-insensitive), `description` (1 to 300), `price_vnd` (1 to 100,000,000) and file field `image` (exactly one, JPEG or PNG by signature, at most 5 MB, 200 to 4096 pixels on each side; ADR-0025). The cake is active at once. 201 returns the cake as in 10.13. Errors: 422 `VALIDATION_FAILED` (field `image` codes `IMAGE_REQUIRED`, `IMAGE_TYPE_UNSUPPORTED`, `IMAGE_DIMENSIONS_INVALID`; field `name` `NAME_TAKEN`; others as above), 413 `PAYLOAD_TOO_LARGE`/`IMAGE_TOO_LARGE`, 409 `CAKE_LIMIT_REACHED` (13th, AC-61). The request is atomic: nothing is stored on any error. A repeat after a lost response answers `NAME_TAKEN`; the client then reads 10.13.

`PATCH /v1/owner/cakes/{id}` any of `name`, `description`, `price_vnd`, `is_active` (the image is not editable); 200. Hiding the last active cake: 409 `LAST_ACTIVE_CAKE` (AC-34). A removed cake: 404. `DELETE /v1/owner/cakes/{id}`: removal (BR-19), 204; last active cake: 409 `LAST_ACTIVE_CAKE` (AC-63); already removed: 404. Effects: the customer catalog drops the cake at its next request, orders containing it get `PRODUCT_UNAVAILABLE`, earlier orders keep stored name, quantity and price (AC-62). Example create fields: `name=Banh Mau`, `description=Banh mau`, `price_vnd=150000`, `image=<JPEG 2 MB>`.

### 10.18 Staff

`GET /v1/owner/staff` returns all accounts (owner first): `account_id`, `name`, `email`, `role`, `is_active`. `POST /v1/owner/staff` body `name` (1 to 100), `email` (valid format); 201 returns the account. Errors: 422 `EMAIL_INVALID`; 409 `EMAIL_TAKEN` (already an account address or the owner's backup address, any letter case; refusal text must not reveal which); 409 `STAFF_LIMIT_REACHED` (31st active). `PATCH /v1/owner/staff/{id}` body `is_active`. Deactivation revokes all sessions of that account in the same transaction, deletes their push tokens and answers 200 (AC-14, FR-7); the owner account: 409 `OWNER_PROTECTED`. Reactivation lets the person sign in again (AC-44). A staff e-mail is never written to a log.

### 10.19 Backup e-mail

`PUT /v1/owner/backup-email` body `email`: valid, different from every account address and from the current backup (409 `EMAIL_TAKEN`, AC-57); creates a `backup_confirm` code for that address and sends it; 202 `{ "expires_in_seconds": 600 }`. Limits: as sign-in codes. `POST /v1/owner/backup-email/confirmation` body `email`, `code`: saves the address (200 `{ "has_backup_email": true }`), sends a notice to the owner address and to the old backup address. Errors `CODE_INVALID`, `CODE_EXPIRED`, `CODE_LOCKED`. The old address stays valid until the new code is confirmed.
