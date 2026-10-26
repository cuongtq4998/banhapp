# ADR-0017: Catalog validators, read rate limit and versioned asset URLs

| Field    | Value |
| -------- | ----- |
| ADR      | 0017 |
| Status   | Accepted |
| Date     | 2026-10-26 |
| Decider  | atlas-architect |
| Based on | QA findings DOC-1 to DOC-7 and DOC-10 (docs/test/place-order-tests.md); ADR-0011, ADR-0013, ADR-0014; owner decision of 2026-10-26 on the catalog |

## Context

Slice 1 serves the catalog and static images. The documents left open the ETag meaning, the shape of the read rate limit, the image field and folder, image caching when a photo changes, and what the catalog does with fewer than four cakes. None of these costs money, touches customer data or changes visible behaviour beyond the owner decision below, so they are technical decisions.

Owner decision (business): the catalog shows every active cake; one to four are normal; only zero active cakes is an error.

## Options Considered

| Topic | Options |
| ----- | ------- |
| ETag | (A) strong tag from a hash of the body bytes; (B) weak tag from a data version counter; (C) none, always 200 |
| Read rate limit | (A) one shared budget per address; (B) per route; (C) shared, with static files exempt |
| Image caching | (A) 24 h `max-age` on stable names (stale photo for a day); (B) `no-cache` and ETag on every image (a request per image per launch); (C) content version in the URL and a one-year `immutable` cache; (D) hand-versioned file names |

## Decision

1. **Catalog ETag (A).** Strong tag: quoted lowercase hex of the SHA-256 of the exact body bytes, truncated to 32 characters. The body is encoded deterministically. `If-None-Match` uses weak comparison (list, `W/` ignored, `*`). A 304 repeats `ETag`, `Cache-Control: no-cache` and `X-Request-Id`. Details: api.md 4.1. A version counter (B) would need a column that every later owner edit must maintain; a body hash needs nothing and cannot be forgotten.
2. **Rate limit (A).** One shared fixed 60-second budget per address for all read routes; 304 and 404 count, a 429 does not; `Retry-After` is the seconds left in the window (1 to 60). 120 per minute stays: a cold start is about five requests (one catalog, four images, then cached for a year), so one address can start about 20 customers a minute; the shop expects a few orders a day. Counting everything keeps the limiter a plain counter with no per-route rules. If shared mobile gateways prove too tight, raise `RATE_LIMIT_READ_PER_MINUTE`, or exempt static files (C), without an API change; the 429 alert (deployment.md) shows it.
3. **Image field.** Column `product.image_path` (relative, `images/<slug>.png`), API field `image_url`, built as base + `/assets/` + path + `?v=` (below). Folder `backend/assets/images/`, served at `/assets/images/*` only.
4. **Image caching (C).** The server appends `?v=<first 8 hex of the file SHA-256>` computed at start, and answers images with `public, max-age=31536000, immutable`; 404 gets `no-store`. A changed photo changes the URL, and so the catalog ETag, so apps fetch the new one. No manual naming rule to forget (D), no per-image request (B).
5. **Unknown query parameters** on `GET /v1/catalog` and `GET /v1/availability` are ignored (the request-body rule of rejecting unknown fields stays for `POST`).
6. **`note_max_length`** is a code constant (200, an input-safety bound under ADR-0009), returned in `settings`; it is not a `shop_setting` column.
7. **Catalog size.** `products` holds every active product, with no minimum or maximum; zero active returns 200 with `[]` and the apps show the error screen. Order `items` is limited to the number of active products and the availability `cakes` bound is `max_qty_per_cake` times that number.
8. **Seed and example wording; fake phone.** Nothing that can reach a screen carries a sample marker. Seed `phone_contact` is `+849000000NN` (NN 00 to 99) so it passes `^0[35789][0-9]{8}$` after normalisation; `zalo_contact` the same without `+`.

## Consequences

- Positive: cheap revalidation (a 304 costs no body), no stale photo, no new column, clear limiter rules testable by one counter.
- Negative: the server hashes the image files at start (four files); replacing a photo needs a redeploy (the files are inside the image anyway); the body must stay deterministic (a developer test pins it).
- Follow-up: the Dockerfile must copy `backend/assets` (developer query); the static handler must ignore the query and reject `..`.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| A 304 response must repeat `ETag`, `Cache-Control`, `Content-Location`, `Date`, `Expires`, `Vary` when they would be sent in a 200 | https://www.rfc-editor.org/rfc/rfc9110.html (section 15.4.5) | 2026-10-26 | High |
| `If-None-Match` uses weak comparison; a list and `*` are allowed; `Retry-After` is seconds or an HTTP date | RFC 9110 sections 13.1.2 and 10.2.3 (not read in this session, known from the standard) | 2026-10-26 | Medium |
| Versioned URLs with a long `max-age` (and optionally `immutable`) are the recommended way to cache assets that can change; `no-cache` with `ETag` for URLs that cannot be versioned | https://web.dev/articles/http-cache | 2026-10-26 | High |
| Several customers can share one address behind a mobile carrier gateway | General knowledge of carrier-grade NAT (not fetched); QA question Q-A8 | 2026-10-26 | Low |
| No official reserved range of fictional Vietnamese mobile numbers found | Not searched in depth | 2026-10-26 | Unverified |

## Links

Related: ADR-0011, ADR-0013, ADR-0014; api.md sections 1, 4.1, 4.6.
