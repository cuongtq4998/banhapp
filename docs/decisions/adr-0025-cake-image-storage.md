# ADR-0025: Storage and delivery of cake images uploaded by the owner

| Field    | Value |
| -------- | ----- |
| ADR      | 0025 |
| Version  | 1.1 [v1.1 | 2026-10-31] |
| Status   | Accepted (no cost; no customer data; reversible by a migration to object storage) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD admin-orders v1.6 FR-21, BR-12, AC-33 (ids as in product/admin-orders/08, section 15); TQ-6; ADR-0003, ADR-0017; api/04 section 4.6 |

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

Photo handling on the device (TQ-D1) [v1.1 | 2026-10-31]: the picker may return HEIC or large photos. The app always decodes the picked image and re-encodes it as JPEG (longest side 1600 px, quality 80, flattened on white if it had transparency), so HEIC never reaches the server and the 5 MB rule is met in practice; if decoding fails the app shows the unsupported-picture message. The upload is ONE multipart request (`POST /v1/owner/cakes`: text fields and file together), atomic on the server; there is no two-step upload and no orphan image. Android decoding of HEIC on API 26 and 27 is unverified (the picker normally hands over a decodable JPEG); forge-dev spike.

Server limits (R-16) [v1.1 | 2026-10-31]: "5 MB" means 5,242,880 bytes (`IMAGE_MAX_BYTES`) for the file part: exactly that size passes, one byte more answers 413 `IMAGE_TOO_LARGE`. The request body limit of this one route is `IMAGE_MAX_BYTES` + 65,536 (form fields and boundaries) = 5,308,416 bytes; a `Content-Length` above it is refused before any body is read, and a streamed body is cut off at it (413 `PAYLOAD_TOO_LARGE`). Authentication and the owner role are checked before the body is collected, so an anonymous caller cannot make the server buffer 5 MB. At most 2 uploads are processed at once (a counter in the service; the third waits up to 5 s, then 503), which bounds memory to about 11 MB on the 512 MB host. Every other route keeps the 8 KB limit. Server checks on upload (multipart field `image`): body limit as above; the file signature decides the type (JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`), never the header or file name; GIF, WebP, HEIC and the rest are refused; the width and height are read from the header and must be 200 to 4096 pixels (refuses decompression bombs without decoding); size above 5 MB is `IMAGE_TOO_LARGE`. The server does not re-encode (no image library on Linux is needed); the owner is a trusted, authenticated uploader.

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
