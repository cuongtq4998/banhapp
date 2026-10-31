# Admin Orders Test Plan: Document review, contradictions and untestable items (part 08)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.0). Holds: section 9.1 review of PRD v1.2 and the related system documents. Owner = who must answer. `requirements` = scribe-requirements, `architect` = atlas-architect, `design` = canvas-ui. [v1.0 | 2026-10-31]

Reviewed: `docs/product/admin-orders.md` and parts 01 to 07; `docs/system/auth.md` v1.5, `order-lifecycle.md`, `api/01-conventions-and-index.md`. No admin design document or admin API exists yet. [v1.0 | 2026-10-31]

## 9.1 Contradictions and gaps

| ID | Finding | Documents | Owner | Cases |
| -- | ------- | --------- | ----- | ----- |
| R-3 | Anyone can lock the owner out: 5 wrong codes (BR-5) block the owner address for 15 min, and 3 code requests an hour can be used up by an attacker; repeated every 15 min the owner can never sign in. It is unclear whether recovery (BR-17) is also blocked. Severity high if confirmed | BR-5, BR-17, FR-6 | requirements (rule), architect (TQ-10) | TC-B14, B52 |
| R-10 | `auth.md` section 4 says cancelled orders count toward 5 orders per phone per 24 h; BR-16/FR-44 say they do not (except spam). `auth.md` also still describes phone and SMS sign-in and "later slice" staff roles | auth.md vs PRD | architect | TC-B98 |
| R-16 | Body limit 8 KB for every route (`api.md` conventions) contradicts cake upload of up to 5 MB (BR-18). Also iPhone photos are HEIC, but BR-18 allows only JPEG and PNG, and "5 MB" is not defined as 5 000 000 or 5 242 880 bytes | api.md, BR-18, TQ-6 | architect (limit and conversion), requirements (unit) | TC-B128, B129, C28 |
| R-20 | AC-59 says recovery "is not offered" without a backup e-mail, but FR-1 says the response must not reveal whether an address is registered. How does the app know to offer recovery without revealing which address is the owner | FR-1, FR-43, AC-59 | requirements, design | TC-B46, B48 |
| R-21 | FR-20 (history) is Should, but AC-26 (Must) requires the history to show the change, and BR-4 (recording, immutable) is a rule with no priority. Priority of FR-20 and AC-31 is inconsistent | FR-16, FR-20, AC-26, AC-31 | requirements | TC-B65, B76 |
| R-25 | Place Order PRD, design and customer apps assume four cakes with fixed photos; the admin PRD says up to 12 cakes with owner images and changed rules text. Place Order documents and ACs need updating (also for FR-44 per section 9) | admin 9, place-order | requirements (place-order), design | TC-C43, F07 |
| R-32 | Reference screens A1 to A4 show phone sign-in and "remembered N days"; PRD says e-mail and 7 days. Design must be redone before UI cases get exact texts | section 9 | design | TC-C01 |
| R-2 | A Confirmed order older than 90 days cannot be opened, so it stays Confirmed forever and nobody can complete it; the shop has no way to close it. Business consequence not discussed | BR-20, BR-2 | requirements | TC-B83 |
| R-8 | FR-19 does not say what happens when the same status change arrives twice (double tap, retry after lost response). "Refused" would show an error after a success | FR-19, AC-30 | requirements (behaviour), architect (TQ-5) | TC-B72, C31, C35 |
| R-11 | BR-9 forbids minimum cakes above the daily limit in one form, but not lowering the daily limit alone below the current minimum (or raising min above limit via a separate save) | BR-9, BR-10, AC-66 | requirements | TC-B109 |
| R-18 | Reactivating a staff account when 30 are already active is not defined (AC-43 only covers adding) | FR-27, BR-8 | requirements | TC-B118 |
| R-5 | Boundaries not defined: code valid "10 minutes" (is minute 10:00 valid), session "7 days", lock "15 minutes", 90 days (inclusive? by timestamp or calendar day in shop time) | BR-5, BR-6, BR-20, AC-4, AC-67 | requirements | TC-B06, B10, B24, B82 |
| R-4 | After a 15-minute lock, is the old code still valid (it expires after 10 min), does a new request reset the wrong-code counter, can codes be requested while locked, and do unregistered addresses lock the same way | BR-5, AC-8 | requirements | TC-B10, B13 |
| R-6 | No limit per client address for code requests or for admin routes; only per e-mail. Mail flooding of many third-party addresses is only stopped for unregistered ones (no mail sent) | BR-5, NFR security | architect | TC-B22 |
| R-7 | Recovery codes: counters and hourly limits shared with normal sign-in codes or separate; notice mail rate | BR-17, TQ-10 | architect | TC-B50 |
| R-12 | A harmless retry of the renewal request (lost response) would look like credential reuse and sign out the legitimate device (FR-36). Grace window or not | FR-36, AC-54 | architect (TQ-4) | TC-B28 |
| R-15 | "Valid phone number" and "Zalo: as the customer app uses it" have no written format | BR-9, FR-26, AC-41 | requirements / architect | TC-B115 |
| R-13 | Search rules unclear: diacritics, case, minimum length, normalisation (NFC/NFD) of names | FR-11, BR-9 | requirements | TC-B59, B139 |
| R-14 | List consistency while paging with changes (new order, status change) is not specified; AC-23 says only "no duplicate" | BR-13, AC-23 | architect | TC-B62 |
| R-17 | Two owner devices editing the same setting: lost update allowed or not | FR-28, FR-30 | architect | TC-B141 |
| R-19 | BR-15 "removed from the device" does not mention app-switcher snapshots, backups or screenshots | BR-15 | requirements, design | TC-C42 |
| R-23 | BR-10 "the owner is told before saving": is this a server preview (testable) or client-only calculation; AC-38 gives no race rule | BR-10, AC-38 | architect | TC-B108, B110 |
| R-29 | "Device name" in the device list (FR-37) has no source (user typed, model name, OS) | FR-37, TQ-9 | architect, design | TC-B36 |
| R-30 | FR-35 push stop when sign-out happens offline (server never told): push continues until token is dropped | FR-35 | architect (TQ-3) | TC-B88, C41 |
| R-28 | "Valid e-mail format" is undefined (AC-43) | AC-43, BR-7 | requirements | TC-B19, B117 |
| R-34 | BR-15 says no customer data in "analytics", but no analytics exist or are specified; only logs are testable | BR-15 | requirements | TC-B92 |

## 9.2 Untestable or only partly testable items

| ID | Item | Why | Owner |
| -- | ---- | --- | ----- |
| R-9 | G-1 "open in at most 2 taps" and G-2 "1 action and at most 1 confirmation step": goals with no AC. Cancel needs reason choice plus confirmation, so "1 confirmation step" must be defined as one screen | no AC | requirements |
| R-22 | "Within 60 seconds in normal network conditions" (AC-48), "within 5 minutes" (AC-14, AC-55, proposed bound), e-mail "within 60 seconds": needs real services; "normal conditions" is not measurable | AC-48, BR-8, NFR | requirements (define), architect |
| R-31 | Performance figures are "proposed" and say "normal mobile connection": only server time can be measured here | NFR | requirements |
| R-33 | FR-30 "every settings change" is Should and does not say whether staff, device and backup e-mail changes are included | FR-30 | requirements |
| R-26 | A-10 says "proposed" values may change; tests read configuration, but the PRD gives no way for the owner to see a changed value, so documents can drift | A-10 | requirements |
| R-24 | Stale labels: parts 01 to 06 say "PRD v1.1" while the index is v1.2; `order-lifecycle.md` calls staff features "later slice" | doc hygiene | requirements, architect |
