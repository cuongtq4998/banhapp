# ADR-0011: Offline caching of shop data and survival of the in-progress order

| Field    | Value |
| -------- | ----- |
| ADR      | 0011 |
| Status   | Accepted |
| Date     | 2026-10-25 |
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

**The order flow always needs the network.** Dates (S-6) require a fresh `GET /v1/availability`; no cached availability is used. S-5 may use cached prices for display but refreshes the catalog on entry; the server price check (ADR-0010) is the final guard. If offline at S-6, the screen shows `DATE_ERR` with retry.

**Draft (2).** The app persists the draft (items, date, slot, name, phone, address, district, note, idempotency key, saved time) to app-private storage on every change, restores it after process death, deletes it after a confirmed order, and discards it after 24 hours without change. It is excluded from device backups and cloud sync (iOS: file with `isExcludedFromBackup` and complete data protection; Android: `no_backup` directory or exclusion rule, DataStore). On the first launch after a restore, tapping "Place order" on S-2 opens S-5 with the restored data; entering from a cake detail (S-4) starts a new draft with that cake at 1 (UI section 5.4). No prompt is shown.

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

Related: ADR-0007, ADR-0008, ADR-0010.
