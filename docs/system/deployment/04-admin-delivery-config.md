# Deployment and Operations: Admin apps, mail, push, images

Part of [deployment.md](../deployment.md) (index, version, change log), sections 11 to 18. New in v1.10 [v1.10 | 2026-10-31]. Placeholders only; no hosts, keys or account ids.

## 11. Configuration added (backend)

| Name | Meaning | Required | Where set |
| ---- | ------- | -------- | --------- |
| `AUTH_CODE_PEPPER` | Secret for HMAC of codes (32 random bytes, base64) | Yes in staging and production | Host secret store |
| `ACCESS_TOKEN_TTL_SECONDS` | Default 300 | No | Host |
| `REFRESH_TOKEN_TTL_DAYS` | Default 7 | No | Host |
| `REFRESH_GRACE_SECONDS` | Default 20 | No | Host |
| `AUTH_FIXED_CODE` | Fixed code for tests; refused at start when `APP_ENV=production` | No (local, staging) | Local and staging only |
| `MAIL_PROVIDER` | Selects the `EmailSender` implementation: `recording` (tests), `console` (local only), `resend` (live, needs domain; ADR-0023). Code above the sender is the same for all [v1.11 | 2026-10-31] | Yes | Host |
| `MAIL_API_KEY` | Provider key | Yes with `resend` | Host secret store |
| `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` | Sender on the verified domain, for example `no-reply@mail.<SHOP_DOMAIN>` | Yes with `resend` | Host |
| `MAIL_MAX_PER_DAY` | Default 80 | No | Host |
| `PUSH_PROVIDER` | `live`, `recording` (tests), `off` | Yes (default `off` locally) | Host |
| `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC` | APNs provider token; topic is the admin bundle id | With `live` | Host secret store |
| `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON` | FCM v1 | With `live` | Host secret store |
| `RATE_LIMIT_ADMIN_PER_MINUTE` | Default 240 per device session | No | Host |
| `RATE_LIMIT_CODE_REQUEST_PER_HOUR_IP` | Default 20 | No | Host |
| `RATE_LIMIT_AUTH_PER_HOUR_IP` | Default 60 (sessions, refresh, recovery per client address) [v1.11 | 2026-10-31] | No | Host |
| `IMAGE_MAX_BYTES` | Default 5242880; the cake upload route body limit is this plus 65536 [v1.11 | 2026-10-31] | No | Host |
| `REVIEW_ACCOUNT_EMAIL`, `REVIEW_ACCOUNT_CODE` | Only while ADR-0027 is enabled | No | Host secret store, removed after review |

`.env.example` lists the names with empty values. Startup checks (fail fast): `AUTH_FIXED_CODE`, `console` mail or `recording` providers with `APP_ENV=production`; `AUTH_CODE_PEPPER` shorter than 32 bytes. Operator commands (run with the application role): `bootstrap-owner --email <EMAIL> --name <NAME>`, `review-account on|off`.

Mobile build settings: `API_BASE_URL` per configuration as for the customer apps; iOS capability Push Notifications (entitlement `aps-environment`); Android `POST_NOTIFICATIONS` permission (Android 13 and later), notification channel `new_orders` importance HIGH (ADR-0024 v1.1), `allowBackup=false` and data-extraction rules, `FLAG_SECURE` on order screens (architecture/08 24.2), `google-services` configuration kept out of the repository or with only non-secret ids (unverified: confirm the file holds no secret before committing).

## 12. Environments (addition)

| Environment | Admin specifics |
| ----------- | --------------- |
| local | (free, no accounts) `MAIL_PROVIDER=console` prints the code on stdout; `PUSH_PROVIDER=off`; owner created with `bootstrap-owner` against the local container |
| staging | Free host. Recording or console senders by default; a real mail provider only to the operator's own mailbox if it works without a domain (ADR-0023, unverified) [v1.11 | 2026-10-31]; `AUTH_FIXED_CODE` allowed for automated UI tests; push with the APNs sandbox environment and an FCM test project; fake orders only; store review builds point here only if the review account cannot be used (ADR-0027 option C is not chosen) |
| production | Real provider, real push, no fixed code; the owner account created by the operator at launch |

## 13. Build & Release (admin)

- Workflows: `admin-ios.yml` (macOS runner, Xcode 26.x, `ios/BanhAdmin.xcodeproj`, scheme `BanhAdmin`, project format 77 kept) and `admin-android.yml` (Ubuntu, JDK 17, `:admin`), path-filtered to `ios/BanhAdmin*/**`, `ios/Packages/**`, `contracts/**` (and `android/admin/**`, `android/core/**`, `android/build-logic/**`). The customer workflows add `ios/Packages/**` and `android/core/**` so a shared change tests both apps.
- Backend: `backend.yml` also runs the new migrations, the admin tests (recording mail and push senders, no network) and the staff-token negative tests for every `/v1/owner` route.
- Versioning: tags `admin-ios-vX.Y.Z` and `admin-android-vX.Y.Z`; build numbers increase per upload; API `v1` is shared.
- Store submission notes (unverified until accounts exist):

| Item | Apple App Store | Google Play |
| ---- | --------------- | ----------- |
| Distribution | Unlisted app distribution after review, request form by the account holder (ADR-0026) | Closed testing track with a tester list; production only if needed |
| Privacy | Staff use name, phone, address of customers; e-mail address of staff; not shared; `/privacy` has a staff section | Data safety form: personal info collected, encrypted in transit, not shared, deletion on request to the shop |
| Review access | Review account of ADR-0027 or a live code given to the reviewer | Same |
| Push | APNs key created in the Apple account | Firebase project (free) |

## 14. Infrastructure (addition)

| Component | Choice | Reference |
| --------- | ------ | --------- |
| Mail | `EmailSender` protocol; recording and console senders for development; HTTPS provider adapter (Resend free plan; Brevo fallback) and sender subdomain with SPF, DKIM, DMARC only after the owner approves the domain | ADR-0023 |
| Push | APNs and FCM, both free | ADR-0024 |
| Images | Bytes in PostgreSQL (`product_image`), covered by the nightly dump; no object storage | ADR-0025 |
| Hosting | Free trial plans for development and tests only (owner, 2026-10-31); real use needs the paid always-on path, NOT yet approved (cold start breaks the 60 s mail target; background push needs a running process) | ADR-0003 v1.5 [v1.11 | 2026-10-31] |
| Domain | One domain for the API host and the mail subdomain (owner purchase) | ADR-0023, R-8 |

## 15. Backup & Restore (addition)

Images and all admin tables are in the same dump. The restore test (section 6) adds: restore into a scratch database, check that the count of uploaded cakes equals the count of `product_image` rows, that `device_session` rows are present but treated as expired (the operator revokes all sessions after a restore: `UPDATE device_session SET revoked_at = now(), revoked_reason = 'expired_cleanup'`, so a restored database never revives old credentials), and that no `auth_code` is usable.

## 16. Observability and alerts (addition)

Log fields stay as section 7; the admin routes add role but never e-mail address, token, code or customer data. Alerts (each owner: operator):

| Alert | Threshold | Action |
| ----- | --------- | ------ |
| Mail send failures | 3 consecutive provider errors or any 4xx for the sender domain | Check key, domain status, provider status; staff can wait or use an already signed-in device |
| Mail daily cap use | Above 60 of 80 | Look for abuse in `CODE_REQUEST_LIMIT` counts (a stranger can use up the cap, which also delays recovery; the operator recovers, A-7); raise the cap or block |
| Push failures | More than 20 percent of sends fail in an hour | Check APNs key and FCM account; list still works |
| `refresh_reuse_detected` | 3 in a day | Ask the owner to review the device list |
| Voided codes | More than 10 log lines `code_voided` (5th wrong entry; no address in the line) in an hour | Possible guessing or a prank; there is no lock, so nothing is blocked; look at request ids |
| Orders without a push record | More than 1 percent over 30 days | Decide on an outbox (ADR-0024) |
| Database size | Above 80 percent of 1 GB (images and history count) | Plan upgrade (owner approval) |

## 17. Cost notes (estimates) and launch checklist

| Item | Estimate | Source |
| ---- | -------- | ------ |
| Mail provider | USD 0 at this volume on a free plan | ADR-0023 (medium) |
| Domain | About USD 10 to 15 a year | deployment.md section 9 (unverified) |
| Push | USD 0 | ADR-0024 (unverified) |
| Store fees | Already planned for the customer app (USD 99 a year, USD 25 once, unverified); no second fee for the admin app | ADR-0026 |
| Hosting | USD 0 on trial; about USD 7 per month API plus USD 15 to 20 database for real use | ADR-0003 |

Money items needing owner approval, all NOT approved on 2026-10-31 (free tier only): domain, paid hosting, store accounts, mail provider account. Admin launch checklist (every line from "ADR-0023" on is blocked until DP-Q4 is approved) [v1.11 | 2026-10-31]: ADR-0022, 0023, 0026, 0027 decided; domain bought and DNS verified, test code mail received at two mailbox providers; APNs key and FCM project created; paid hosting active; owner created by `bootstrap-owner` and backup address confirmed; staff added; device test of push on both platforms; privacy page staff section published; review account disabled after approval; restore test with the admin tables done.

## 18. Free-tier development mode and go-live gate [v1.11 | 2026-10-31]

Owner decision 2026-10-31 (DP-Q4): free tier only for now. What that means for the admin feature:

| Item | Allowed now (free, with fakes) | Blocked until the owner approves money |
| ---- | ------------------------------ | -------------------------------------- |
| Backend, migrations, admin tests, CI | Yes: recording `EmailSender` and `PushSender`, throwaway database, `AUTH_FIXED_CODE` in tests only | None |
| Slices A0 to A5 (architecture/07 section 23) | Built and accepted with fakes and contract fixtures; local run with console mail and `PUSH_PROVIDER=off` | None |
| Free staging service | Fake orders and the operator's own address; sleeps after idle, in-memory limits reset; acceptable for development | Real staff, real customer orders |
| Real code mail to staff | No | Sender domain, mail provider account (ADR-0023) |
| Always-on hosting for real use | No | Paid hosting and database (ADR-0003 v1.5, about USD 7 plus USD 15 to 20 a month, unverified) |
| Push to real devices | Android with an FCM test project may work free (unverified); recording sender in tests | Apple Developer Program for APNs and iOS push (unverified that a free account cannot) |
| Store records, review submission, unlisted request | No | Apple USD 99 a year, Google USD 25 once (unverified); identifiers stay changeable until the first upload (ADR-0026) |

Go-live gate: the system is "ready for staff" only when DP-Q4 is approved and the launch checklist of section 17 is complete. Until then the apps, API and tests are complete against fakes and must not be announced to staff. Code does not change at go-live: the operator sets `MAIL_PROVIDER`, the provider variables, the push keys and the hosting plan.
