# System Architecture: Slice B6 alignment, document corrections, defects D-1 and D-2 closed

Part of [architecture.md](../architecture.md) (index, version, change log), section 29. New in v1.17 [v1.17 | 2026-11-01]. Slice B6 (cakes with images) is built; where the code was the better choice the system documents now follow it. Sources read: `backend/db/migrations/0005_admin_cakes.sql`, `Routes/Admin/OwnerCakeRoutes.swift`, `Routes/CakeImageRoutes.swift`, `Http/UploadSizeGuard.swift`, `Http/RequestLimits.swift`, `Services/Admin/Settings/Cake*`, `ImageInspector`, `MultipartFields`, `UploadGate`, `Repositories/Admin/SettingsWriter+Cakes.swift`, `SettingsQueries.swift`, `contracts/fixtures/admin/owner-cake-*` and `error-cake-*`, `AdminOrderService.changeStatus`. Format as in [12-b4b5-alignment.md](12-b4b5-alignment.md).

## 29.1 Decisions and corrections

| Topic | Rule | Written in |
| ----- | ---- | ---------- |
| Image field codes | Field `image`: no file or an empty file `IMAGE_REQUIRED` (`ERR_FIELD_REQUIRED`); not JPEG or PNG by signature `IMAGE_TYPE_UNSUPPORTED` (`ERR_FIELD_TYPE_UNSUPPORTED`); a side outside 200 to 4096 `IMAGE_DIMENSIONS_INVALID` (`ERR_FIELD_DIMENSIONS_INVALID`); two or more files named `image` `IMAGE_INVALID` (`ERR_FIELD_INVALID`). All join the other field problems in `fields[]` | api/07 10.17, api/08 |
| Two sizes of 413 | A file part above 5,242,880 bytes is 413 `IMAGE_TOO_LARGE` (`ERR_IMAGE_TOO_LARGE`), raised at once, before other field problems are listed. A `Content-Length` above 5,308,416 is 413 `PAYLOAD_TOO_LARGE`, answered by `UploadSizeGuard` before the body is read and only after authentication and the owner role. A body without a length is cut off by the route limit while collected | api/07 10.17, api/05 section 9, ADR-0025 v1.2 |
| Repeated text field | A text field sent twice (or sent as a file) is `<FIELD>_INVALID` (for example `NAME_INVALID`), not "first value wins" | api/07 10.17 |
| Other form problems | A text field outside `name`, `description`, `price_vnd` is `FIELD_UNKNOWN`; a body that is not `multipart/form-data` with a boundary, or cannot be parsed, is 422 `VALIDATION_FAILED` without `fields[]`; `price_vnd` that is not a whole number is `PRICE_VND_INVALID` | api/07 10.17 |
| Upload gate | `UploadGate` lets 2 uploads run at once per process; a third waits 5 s and then gets 503 `SERVICE_UNAVAILABLE` | api/07 10.17, ADR-0025 v1.2 |
| Image delivery | `GET /assets/cakes/{id}?v=<8 hex>` is public, reads `product_image`, answers the stored `Content-Type`, `X-Content-Type-Options: nosniff`, `Cache-Control: public, max-age=31536000, immutable`. Removed cake, unknown id or no stored image: 404 `NOT_FOUND`. The `v` value is not checked (the content cannot change); it only changes the URL | api/07 10.17, ADR-0025 v1.2 |
| Cap trigger | `product_cap_guard` fires `BEFORE INSERT OR UPDATE OF removed_at`. On update it counts only when a removed cake is brought back (`removed_at` set to null); no route does that today, the trigger is the last line of defence. Earlier text said "insert only" | data-model/05 section 12, 15 |
| Cakes list | `GET /v1/owner/settings` lists only `removed_at IS NULL` cakes, ordered by `sort_order`, then id. The customer catalog filters `is_active AND removed_at IS NULL` | api/07 10.13 |
| Removal | One transaction: delete the `product_image` row, set `removed_at` and `is_active = false`, record `is_active` and `removed` in `settings_change` (entity `cake`). Removing the last active cake is `LAST_ACTIVE_CAKE`; removing a hidden cake while others are active is allowed | api/07 10.17, data-model/05 section 12 |
| `PATCH` | Keys `name`, `description`, `price_vnd`, `is_active`; `image` is `FIELD_UNKNOWN`. A rename onto another live name is 422 `NAME_TAKEN`. Unknown or removed id is 404 `NOT_FOUND` | api/07 10.17 |
| Migration | `0005_admin_cakes.sql` holds data-model/05 section 12 and the fix of D-2 | data-model/05 section 15 |

## 29.2 Defects D-1 and D-2 of architecture/11 27.4: fixed in B6

| ID | Fix | Evidence |
| -- | --- | -------- |
| D-1 | `AdminOrderService.changeStatus` falls back to `findIgnoringAge` when the window lookup finds nothing; an exact repeat (same account, same move) answers 200 with `Idempotent-Replay: true`. Any other call on an order outside the window stays 404 | Code comment on `changeStatus`; dev guide B6 paragraph |
| D-2 | `0005` replaces `customer_order_release_capacity`: a cancel of an `is_demo` order does not touch `day_load` | `0005_admin_cakes.sql` |

## 29.3 Other document and code differences found (B6)

| Item | Finding | Resolution |
| ---- | ------- | ---------- |
| Cakes filter (28.2) | Open after B5 | Closed: the filter is in `SettingsQueries` |
| ADR-0025 | Said the counter is "in the service" and described one 413 code | Fixed (v1.2): `UploadGate` in the route layer; two 413 codes |
| data-model/05 section 15 | Said the cake migration is still to come | Fixed: `0005` is built |
| Fixtures | `owner-cake-created.json`, `error-cake-validation.json`, `error-cake-name-taken.json`, `error-cake-limit-reached.json`, `error-last-active-cake.json` agree with the code | None |
| Dev guide | The B6 paragraph matches the code; owned by forge-dev, not edited | None |
| Image 404 cache header | The 404 envelope carries `no-store` from the shared error handling (place-order D-19); not re-verified for this route | Left as in ADR-0025 |

## 29.4 Open defects

None for forge-dev from B6. The QA package has two known failing tests (dev guide), neither caused by B5 or B6. Query for the requirements agent: none. Still open from earlier: purge task, push token route, review-account sign-in (architecture/11 27.2).
