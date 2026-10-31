# ADR-0011: Offline caching of shop data and survival of the in-progress order

| Field    | Value |
| -------- | ----- |
| ADR      | 0011 |
| Status   | Accepted |
| Date     | 2026-10-25 (v1.2 2026-10-28) |
| Decider  | atlas-architect |
| Based on | UI TQ-3, TQ-7; FR-15, FR-17, AC-18, AC-20; PRD section 8 Privacy |

## Context

The customer app reads shop information, products, districts and slots, and needs the server for availability and ordering. Customers in Vietnam may have poor connections. The customer may be interrupted (a call, Zalo) and the system may end the app process.

## Decision Drivers

- Useful browsing on weak connections.
- Never order against stale rules (the server revalidates, but the customer should not be misled).
- Keep personal data on the device to the minimum and short-lived.

## Options Considered

Catalog: (A) always load fresh; (B) cache the last good catalog and show it while refreshing, with ETag revalidation; (C) bundle a copy in the app (stale prices, store review needed to update).

Draft: (1) memory only (lost when the process ends); (2) persist on the device with a short life; (3) persist on the server (needs an identity; rejected).

## Decision

**Catalog (B).** The app stores the last successful `GET /v1/catalog` response (shop information, products, districts, slots, ordering parameters) with its ETag and fetch time. S-2, S-3, S-4 show cached data at once and refresh in the background; a failed refresh keeps the cache silently. The Error states of those screens (`HOME_ERR`, `PRODUCTS_ERR`) appear only when no cache exists. Cache lifetime: shown for up to 7 days; an older cache counts as no cache. Product images use the platform HTTP cache.

**Catalog refresh rule (UI TQ-9)** [v1.1 | 2026-10-26]. The apps send the catalog request at start-up, on every appearance of S-2, S-3 and S-4, and on return to the foreground, always with `If-None-Match` when a cache exists; a 304 keeps the cache and its fetch time moves forward. One shared catalog component serves all screens: at most one request in flight (a second caller waits for it), and at most one background revalidation per 30 seconds (a client constant). The throttle does not apply when no cache exists, on the retry button, and on entry to S-5 (prices). S-2 takes the number of active cakes from this cached catalog: zero products disables "Place order" (`HOME_NO_CAKES`). A failed refresh (offline, timeout, 5xx, 429) keeps the cache and shows nothing, including no error on S-2, as long as a cache younger than 7 days exists; only with no usable cache do the Error states appear. Budget (ADR-0017, 120 read requests per minute per address; 304 counts): a catalog revalidation is one request because images are cached for a year. Without the throttle, one customer moving between S-2 and S-3 every 3 seconds sends 20 per minute; with it, at most 2 background requests per minute plus a few human taps on S-5 and retry, say 6, so at most 8 per minute per customer. A cold start is 5 requests (catalog and four images). Ten customers on one shared address, all active in the same minute and three of them cold starting: 7 x 8 + 3 x (8 + 4) = 92 requests, under 120. Twenty customers all active at once would reach the limit, which is far above the expected load (a few orders a day); a 429 on a refresh is a failed refresh and is silent. If the 429 alert shows it, raise `RATE_LIMIT_READ_PER_MINUTE` (no API change).

**The order flow always needs the network.** Dates (S-6) require a fresh `GET /v1/availability`; no cached availability is used. S-5 may use cached prices for display but refreshes the catalog on entry; the server price check (ADR-0010) is the final guard. If offline at S-6, the screen shows `DATE_ERR` with retry.

**Draft (2).** The app persists the draft (items, date, slot, name, phone, address, district, note, idempotency key, saved time) to app-private storage on every change, restores it after process death, deletes it after a confirmed order, and discards it after 24 hours without change. It is excluded from device backups and cloud sync (iOS: file with `isExcludedFromBackup` and complete data protection; Android: a file in `noBackupFilesDir`; v1.2 below). On the first launch after a restore, tapping "Place order" on S-2 opens S-5 with the restored data; entering from a cake detail (S-4) starts a new draft with that cake at 1 (UI section 5.4). No prompt is shown.

**Hidden cake in the draft (UI TQ-10)** [v1.1 | 2026-10-26]. When the refreshed catalog no longer contains a product that the draft holds, or the server answers `PRODUCT_UNAVAILABLE` on `POST /v1/orders`, the app removes only that item (its quantity) from the draft and shows `ORDER_CAKE_REMOVED` on S-5. The date, slot, name, phone, address, district, note and the other items stay (FR-15, BR-13, AC-34). Because the order content changed, the idempotency key is replaced by a new one; this is one case of the general rule in ADR-0008 v1.1 (new key on every change of the request body, same key for a pure retry). If no item is left, S-5 shows its zero state. A cake made active again is not re-added automatically.

**Draft storage and content (slice 2 review)** [v1.2 | 2026-10-28].

- File stores are accepted on both platforms. iOS: a file in app storage, `isExcludedFromBackup`, `.completeFileProtection`, atomic writes. Android: a JSON file in `noBackupFilesDir` (excluded from backup and device-to-device transfer, private to the app), atomic writes. DataStore is not required: the draft is one small document read at start, so the file meets every property this ADR asks for (private, backup-excluded, restored after process death, 24 hour expiry) with less machinery. Both stores read the saved time, delete an expired or unreadable draft and return "no draft". ADR-0007 is amended accordingly.
- The 24 hour rule applies to both: a draft whose saved time is older than 24 hours is deleted on read.
- Cake-name snapshot accepted. The draft may hold, per item, the cake name as shown when the cake was added, so that `ORDER_CAKE_REMOVED` can name a cake the catalogue no longer lists. A cake name is public shop data, not personal data, and it never leaves the device (the order request sends ids only). iOS stores it per item. Android stores quantities by id only and falls back to the general wording when the name was not seen in the current run; that is acceptable for slice 2, and Android adds a `cakeNames` map (id to name) to the draft when it next touches the draft (slice 3), so both platforms name the cake. The snapshot is never used for display of prices or for the request.

The draft is personal data on the customer's own device: it is listed in `data-model.md` section 7 and in the privacy statement; it never leaves the device except in the order itself.

## Consequences

- Positive: FR-15 also holds across process death; retry after kill reuses the idempotency key (ADR-0008).
- Negative: a stale cache can show an old price for a short time; the review always uses prices fetched when the flow was entered and the server check catches changes.
- Follow-up: UI query to canvas-ui about the S-2/S-3 error rules and the resume behaviour (see report); tests: kill the process on each step, offline launch with and without cache.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| iOS backup exclusion and Android no-backup storage exist as platform features | Platform documentation, not fetched | 2026-10-25 | Unverified |
| HTTP ETag revalidation (`If-None-Match`, 304) | RFC 9110, not fetched | 2026-10-25 | Medium (standard behaviour) |

## Links

Related: ADR-0007, ADR-0008, ADR-0010, ADR-0017.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version (Accepted). |
| 1.1 | 2026-10-26 | Catalog refresh rule with rate-limit budget and silent failure (TQ-9); hidden cake dropped from the draft, other data kept, new idempotency key (TQ-10). Business behaviour is unchanged: it states what BR-13 and AC-34 already require. |
| 1.2 | 2026-10-28 | Slice 2 review: file stores accepted (Android `noBackupFilesDir`, iOS protected file), 24 hour expiry on both, cake-name snapshot accepted, key-replacement pointer to ADR-0008 v1.1. |
