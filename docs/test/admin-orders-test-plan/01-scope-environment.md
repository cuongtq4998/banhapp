# Admin Orders Test Plan: Scope and Environment (part 01)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.0). Holds: section 1 Scope & Environment, case id scheme, fake data. [v1.0 | 2026-10-31]

## 1. Scope & Environment

Mode: EARLY (plan only). No admin code, no admin design document and no admin API document exist yet; the plan is derived from PRD v1.2 (FR-1 to FR-44, BR-1 to BR-21, AC-1 to AC-72) and the Place Order system documents. Every result is `Not run`. No build, test or git command was run. [v1.0 | 2026-10-31]

In scope: admin backend endpoints (sign-in, sessions, devices, recovery, orders, settings, cakes, staff, push), the admin app on iOS and on Android (both, D-2), the contract fixtures, and the effect on Place Order (FR-44, catalog with up to 12 cakes, lead days, minimum cakes, limit). Out of scope: payment, order editing, customer notifications, reports (PRD non-goals). [v1.0 | 2026-10-31]

Endpoint names are not known yet (api.md has no admin section). Cases say "request a code", "refresh", "change status" and so on; the executable tests bind them to the real paths once `docs/system/api` is extended. [v1.0 | 2026-10-31]

## Levels and tooling (proposed; forge-dev confirms in the dev guide)

| Level | Id prefix | Tooling | Where tests live |
| ----- | --------- | ------- | ---------------- |
| Backend API and database | TC-B01 to TC-B143 | HTTP-level tests against real PostgreSQL, parallel requests for races, SQL for assertions, fake mail sink, fake push provider, controlled clock | `backend/Tests/qa/` |
| Admin app, both platforms | TC-C01 to TC-C47 | iOS: XCUITest against a stub backend (simulator iOS 17.5+ and 26.x). Android: Compose UI tests (emulator API 26 and 34). Each TC-C case runs on BOTH platforms; results are recorded per platform (columns iOS, Android) | `ios/qa/`, `android/qa/` |
| Contract fixtures | TC-F01 to TC-F07 | `contracts/fixtures/admin-*.json` decoded by backend, iOS and Android | `contracts/`, each `qa/` |

Real devices only: push delivery through the real push services, the phone dialer, Zalo, e-mail deliverability (TQ-1, TQ-3). Everything else runs against fakes. Anything that cannot run here is marked Blocked with the reason. [v1.0 | 2026-10-31]

## Conventions

- Controlled clock: today `D` = 2026-11-02 (Monday, shop time UTC+7). The server clock is injectable; device clocks are never used.
- Case types: acceptance, negative, edge, regression, extra. Extra cases say why they exist. Result values: Not run, Pass, Fail, Blocked.
- A case "runs on both" in the client part means the same steps on iOS and Android; a platform difference is a defect or a note, never silently skipped.
- Short names for fake accounts (all fake): owner "Chu Mau" `chu.mau@example.com`, backup `chu.mau.backup@example.com`, staff A "Nhan Vien A" `nhanvien.a@example.com`, staff B `nhanvien.b@example.com`, staff C `nhanvien.c@example.com`, unregistered `khong.co@example.com`. Customer phones `+84 900 000 0xx`. Order codes `BT-AAAAAA` style.
- Time values in cases use the clock: "+11 min" means 11 minutes after the code was sent.

## Environment rules for the executable tests

1. Mail sink: the backend writes codes to a test sink (file or in-memory endpoint) when `MAIL_MODE=test`; never to a real mail service. Production configuration refuses `MAIL_MODE=test`.
2. Push fake: `PUSH_MODE=test` records every push (device token, payload) for assertion. Real APNs and FCM are Blocked here.
3. Limits that are "proposed" in the PRD are configuration values; tests read them from configuration so a changed value does not break the test (BR-5, BR-6, BR-8, BR-9, BR-18).
4. Database: PostgreSQL is required for race and trigger cases (TC-B72 to TC-B75, TC-B104, TC-B127). Place Order precedent: no PostgreSQL on this host, so these cases are Blocked locally and run in CI.
5. Logs: the test run captures server logs so TC-B92 can scan for personal data.
