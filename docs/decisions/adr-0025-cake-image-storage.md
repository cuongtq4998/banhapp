# ADR-0025: Storage and delivery of cake images uploaded by the owner

| Field    | Value |
| -------- | ----- |
| ADR      | 0025 |
| Version  | 1.0 |
| Status   | Accepted (no cost; no customer data; reversible by a migration to object storage) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD FR-38, BR-18, AC-60, AC-61; TQ-6; ADR-0003, ADR-0017; api/04 section 4.6 |

## Context

The owner adds up to 12 cakes (active plus hidden), each with one JPEG or PNG up to 5 MB. Today images are files baked into the backend image (`backend/assets/images/`). The free web service has an ephemeral disk, so a file written at run time is lost at the next deploy or restart. Backups must also cover the images.

## Decision Drivers

- Survive restarts and deploys at zero cost.
- Covered by the existing nightly encrypted dump and restore test.
- Customer app keeps the versioned, long-cached image URL of ADR-0017.
- Safe handling of untrusted uploads.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. `bytea` in PostgreSQL, served by the backend (chosen) | Free; transactional with the cake row; in the existing backup; nothing new to operate | Database size (small); every uncached read hits the database |
| B. Object storage (S3-compatible, Cloudflare R2) | Built for files, CDN possible | Account, possible card (R2 card requirement unverified), new secrets, new failure mode, backup separately |
| C. Persistent disk on the host | Simple files | Paid feature on the host; not on the free plan |
| D. GitHub repository files | Free | Public repository: forbidden for customer-facing uploads by process; deploy needed per change |

## Decision

Option A. Table `product_image` holds the bytes (data-model/05). Sizing: the apps resize before upload (longest side 1600 px, JPEG quality 80, about 200 to 500 KB; re-encoding also drops EXIF location data); the server accepts up to 5 MB, so 12 cakes are at most 60 MB, far under the free 1 GB. The bytes of a removed cake are deleted.

Server checks on upload (multipart field `image`): body limit 5 MB plus form overhead on this route only (the global 8 KB limit stays everywhere else); the file signature decides the type (JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`), never the header or file name; GIF, WebP, HEIC and the rest are refused; the width and height are read from the header and must be 200 to 4096 pixels (refuses decompression bombs without decoding); size above 5 MB is `IMAGE_TOO_LARGE`. The server does not re-encode (no image library on Linux is needed); the owner is a trusted, authenticated uploader.

Delivery: the catalog `image_url` of an uploaded cake is `/assets/cakes/<product_id>?v=<8 hex of SHA-256>`; the route returns the stored `Content-Type`, `X-Content-Type-Options: nosniff`, `Cache-Control: public, max-age=31536000, immutable` (the version changes with the content; the image of a cake cannot change, non-goal). A missing or removed image answers 404 `no-store`. The route belongs to the shared read rate-limit group. The catalog may now hold up to 12 products: ADR-0017 "catalog size" and api/02 text change from "one to four" to "one to twelve".

## Consequences

- Positive: no new service, one backup, atomic cake plus image.
- Negative: database reads for images (cached by clients for a year); Neon wakes for a first uncached image; the 5 MB route needs its own body limit and a memory check (512 MB host).
- Follow-up: move to object storage if images exceed 100 MB or a CDN is wanted (new ADR); sample images in the repository stay fake.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Render free web services have an ephemeral filesystem | ADR-0003 (Render docs read 2026-10-25) | 2026-10-25 | Medium |
| Neon free plan 1 GB storage | ADR-0003 | 2026-10-25 | Medium |
| JPEG and PNG signatures | RFC 2083 (PNG) and the JFIF/EXIF specifications, from memory | 2026-10-31 | Medium |
| Cloudflare R2 card requirement | ADR-0003 deployment note, unverified | 2026-10-25 | Unverified |

## Links

Amends ADR-0017 (catalog size, image source). Related: ADR-0003, ADR-0031.
