# Place Order Test Report: Scope, traceability matrix and test data

Part of the place-order test plan and report, v1.7 (index: [place-order-tests.md](../place-order-tests.md)). Sections in this part: 1. Scope and Environment, 2. Traceability Matrix, 3. Test data and environment needs. Section numbers and ids are unchanged from v1.6.

| Ids in this part | Range |
| ---------------- | ----- |
| Test cases defined (table rows) | none |
| Test cases mentioned | TC-1 to TC-267 (121) |
| Slice 1 plan ids defined (TC-S1) | none |
| Defects mentioned | D-15 to D-20 (2) |

## 1. Scope & Environment

[v1.5 | 2026-10-26] Round 5 (slice 1 backend retest, execute mode) on commit a934ae8 (feature/place-order tip: slice 1 backend, `contracts/fixtures/catalog-*.json`, ADR-0017, PRD v1.4, api.md v1.6). Host: macOS arm64, Swift 6.2.4, no PostgreSQL, no Docker. Database tests (49 QA, 16 developer) cannot run here; GitHub CI run 40299261388 (backend, a934ae8) was read with `gh`: it failed at "Backend build and unit tests", so every later step (contracts, migrations, seed, **QA package**, release smoke test) was skipped. Result: the database-backed catalogue tests have **no run evidence at all** (neither host nor CI). Details in section 4.6, 6 (round 5), 7 (D-15 to D-20), 8.

[v1.4 | 2026-10-26] Slice 1 (read-only catalogue and shop info), early execute mode on base commit e9c097b (worktree of probe-qa, uncommitted QA files). The slice 1 backend (`GET /v1/catalog`, rate limiter, `/privacy`, `/assets/*`) and both client slices are being written in other worktrees and are **not in this commit**, so the new QA tests were written from api.md v1.5, ADR-0011/0013/0014/0015 and the UI spec, compile and run, and are **expected to fail** (or skip) until the backend instance merges. Same host as before (macOS arm64, Swift 6.2.4, no PostgreSQL, no Docker). No verdict for slice 1 yet. Details in section 4.5.

[v1.2 | 2026-10-26] Round 2 (execute mode, slice 0) ran on commit b613c6d (feature/place-order tip, after forge-dev backend round 2 and the orchestrator workflow fixes). Same host as round 1: macOS arm64, Swift 6.2.4, no PostgreSQL, no Docker, so database tests (21 QA, 10 developer) are skipped, not passed. The QA package was adapted to the new APIs (`app.services.repositories.makeDatabaseProbe` instead of `app.databaseProbe`, `configure(_:config:)`, `configureMigrator` with `MigrationConfig`). GitHub CI was not observable by me; workflows were reviewed by reading only.

[v1.1 | 2026-10-26] Round 1 (execute mode, slice 0 only) ran on commit f940495 (feature/place-order). Slice 0 = `/healthz`, migration `0001_init.sql`, sample seed, config validation, repository layout, CI workflows, empty iOS and Android shells (architecture.md section 11). Host: macOS arm64, Swift 6.2.4, no PostgreSQL, no Docker, no psql, so database-level tests are written and compile but are **unrun here** (they skip unless `DATABASE_MIGRATION_URL` points at a throwaway PostgreSQL 14+). A backend fix round by forge-dev is in flight; results below apply to f940495 only. The remainder of this section is the v1.0 early-mode text.

Mode: EARLY (plan only) in v1.0; v1.1 adds execute mode for slice 0 (see above). The code does not exist. Every result is `Not run`. This version is a test plan plus a review of the document set. No build, test or git command was run.

In scope: the Customer app on iOS and Android (S-1 to S-9) and the backend (Swift Vapor, PostgreSQL; owner decision, final) from launch to the confirmation screen. Out of scope: staff and owner features, payment, tracking, cancellation endpoints (BR-9 is tested at database level only, see TC-59).

Levels:

| Level | Prefix | Tooling (proposed; forge-dev to confirm in the dev guide) |
| ----- | ------ | --------------------------------------------------------- |
| API / backend (including database) | TC-1 to TC-70 | HTTP-level tests against a real PostgreSQL, parallel requests for races, SQL access for assertions |
| iOS UI | TC-101 to TC-165 | XCTest / XCUITest against a stub or test backend, simulator iOS 17.x and 26.x; real device for Zalo and dialer |
| Android UI | TC-201 to TC-267 | Compose UI tests and instrumented tests, emulator API 26 and API 31+ (or newer); real device for Zalo and dialer |

Environment needs are in section 3. Commands: `CLAUDE.md` still describes the template Xcode project (iOS 15, multiplatform, no backend); the real commands are unknown until the dev guide exists (see Q-P1).

Conventions in the cases: today `D` = 2026-11-02 (Monday, shop time) from the controlled clock. Fake seed (section 3): DAILY_LIMIT 10, LEAD_DAYS 2, MIN_QTY 2, MAX_DAYS_AHEAD 30; cakes A 50000, B 60000, C 70000, E 40000 VND; districts Q1 fee 20000, Q2 fee 30000, Q3 inactive; slots S1 08:00-10:00, S2 10:00-12:00, S3 14:00-16:00. Date fixtures: 2026-11-10 has 8 cakes accepted (remaining 2), 2026-11-11 has 10 (full), 2026-11-12 has 9 (remaining 1), 2026-11-13 empty (remaining 10). "Order X" means a valid body for the stated items and date unless a field is named.

Types: acceptance, negative, edge, regression, extra. Result values: Not run, Pass, Fail, Blocked.

## 2. Traceability Matrix

| AC | Requirement | Cases (API) | Cases (iOS) | Cases (Android) |
| -- | ----------- | ----------- | ----------- | --------------- |
| AC-1 | FR-1 | | TC-101 | TC-201 |
| AC-2 | FR-2 | TC-1, TC-69 | TC-102, TC-132 | TC-202, TC-232 |
| AC-3 | FR-2 | TC-69 | TC-103, TC-104, TC-105 | TC-203, TC-204, TC-205 |
| AC-4 | FR-3 | TC-1 | TC-106, TC-107, TC-133 | TC-206, TC-207, TC-233 |
| AC-5 | FR-4 | | TC-108, TC-134 | TC-208, TC-234 |
| AC-6 | FR-5 | TC-16 | TC-109 | TC-209 |
| AC-7 | FR-6, BR-2 | TC-4, TC-5, TC-23, TC-24, TC-62 | TC-110 | TC-210 |
| AC-8 | FR-6, BR-1 | TC-7 | TC-111 | TC-211 |
| AC-9 | FR-10, BR-1 | TC-17 | TC-113 | TC-213 |
| AC-10 | FR-7, BR-11 | TC-1, TC-8 | TC-114 | TC-214 |
| AC-11 | FR-8, BR-3 | TC-1, TC-26 | TC-115 | TC-215 |
| AC-12 | FR-13 | TC-27, TC-28, TC-29 | TC-116 | TC-216 |
| AC-13 | FR-10, BR-4 | TC-22 | TC-117 | TC-217 |
| AC-14 | FR-9, BR-5 | TC-15 | TC-118 | TC-218 |
| AC-15 | FR-11, BR-7 | TC-12, TC-13 | TC-119 | TC-219 |
| AC-16 | FR-11 | TC-14, TC-64 | TC-120 | TC-220 |
| AC-17 | FR-12 | | TC-121 | TC-221 |
| AC-18 | FR-15 | | TC-122 | TC-222 |
| AC-19 | FR-16 | TC-36, TC-37 | TC-123, TC-144 | TC-223, TC-244 |
| AC-20 | FR-17 | TC-54 | TC-124 | TC-224 |
| AC-21 | FR-14 | TC-56 | TC-125 | TC-225 |
| AC-22 | BR-1 | TC-18, TC-19 | TC-126 | TC-226 |
| AC-23 | BR-6 | TC-43, TC-45 | TC-127 | TC-227 |
| AC-24 | FR-6, BR-8 | TC-6, TC-25 | TC-112 | TC-212 |
| AC-25 | FR-11 | TC-13 | TC-128 | TC-228 |
| AC-26 | FR-18 | TC-32 | TC-129 | TC-229 |
| AC-27 | FR-19 | TC-2, TC-13 | TC-130 | TC-230 |
| AC-28 | BR-1, BR-9 | TC-59 (database level only) | not applicable (no UI) | not applicable (no UI) |
| AC-29 | FR-2, FR-3 | TC-2, TC-66 | TC-131 | TC-231 |

All 29 ACs have at least one case. AC-23 and AC-28 can only be proven at database level in this slice (no screen or endpoint shows a stored order); see Q-S4 and Q-S5.

## 3. Test data and environment needs (what forge-dev must provide)

| # | Need | Detail | Used by |
| - | ---- | ------ | ------- |
| E-1 | Controllable clock | Backend: an injectable clock (config or test-only endpoint/env, never in production) to set "now" to an instant such as 2026-11-02T00:00:00+07:00, 23:59:59+07:00, and 2026-11-02T17:30:00Z (= 00:30 on 11-03 shop time), and to move it during a test (midnight crossing, 24 h window). Apps: an injectable clock/date provider so the UI tests run with `server_date` fixed. | TC-4 to TC-6, TC-23 to TC-25, TC-49, TC-62, TC-110, TC-112, TC-142, TC-146 |
| E-2 | Seed data | A test seed (separate from `sample.sql`, or the same with the values above) with `is_sample = true`: four cakes, three districts (one inactive), three slots, DAILY_LIMIT 10, settings per section 1, `day_load` rows for the date fixtures. A reset script to restore the seed before each test class. | all |
| E-3 | Database access in tests | Direct SQL for assertions (orders, items, `day_load`, `order_event`), for price/fee/district/product changes between calls (TC-43, TC-44, TC-46), for the reconciliation query (TC-61), and for status changes (TC-59, TC-60). | API |
| E-4 | Test mode flags | `ORDERING_ENABLED`, rate-limit values (`RATE_LIMIT_*`, `ORDER_MAX_PER_PHONE_PER_DAY`) and `TRUST_PROXY` settable per test run; a way to reset the in-memory limiter between tests; a hook to force order-code collisions (fixed random source) for TC-64; a hook to make the database unreachable (TC-54). | TC-48 to TC-54, TC-64 |
| E-5 | Stub or fault-injecting backend for UI tests | A local stub server (or protocol/interface fake in the apps) that can return, on demand: each error code in api.md section 5, delays over 10 s, no connection, 304, availability that changes between calls, `PRICE_CHANGED` with details. Contract fixtures `contracts/fixtures/` shared by the three suites (architecture.md). | TC-105, TC-113, TC-123 to TC-127, TC-138, TC-155 to TC-157 and Android mirrors |
| E-6 | Test accessibility ids | Stable accessibility identifiers / test tags for every control, field, error message and state in UI sections 5.1 to 5.9, and the localisation keys exposed so tests can assert text by key. | UI |
| E-7 | Fake assets | Four placeholder images, logo, one broken image URL. No real data. | UI, TC-67 |
| E-8 | Devices | iOS simulator 17.x and 26.x; real iPhone with and without the Zalo app and with a SIM-less dialer check. Android emulators API 26, API 30, API 31+ (latest); real Android phone with and without Zalo. Simulators cannot place calls; Zalo behaviour is unverified (ADR-0015), so TC-103/203 and TC-104/204 are `Blocked` until a device is available. | TC-103, TC-104, TC-121 |
| E-9 | Concurrency harness | A test client that sends N requests at the same instant (barrier) against a real PostgreSQL service container (as in deployment.md section 5 step 1). | TC-18, TC-19, TC-37 |
| E-10 | Log capture | Access to backend log output of a test run to check no personal data is logged (TC-65). | TC-65 |
| E-11 | Commands | A dev guide with the exact build, unit, integration and UI test commands for the Vapor backend, iOS and Android; `CLAUDE.md` updated (it still shows iOS 15 / multiplatform). | all |
| E-12 | Fake personal data | Names such as "Nguyen Van A" / "Nguyễn Văn A", phones `0900000000` to `0900000099` (fake range), address "1 Duong Mau". No real data anywhere. | all |
