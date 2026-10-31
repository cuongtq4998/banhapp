# Admin Orders Test Plan: Scope and Environment (part 01)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.1). Holds: section 1 Scope & Environment, case id scheme, fake data. [v1.1 | 2026-10-31]

## 1. Scope & Environment

Mode: EARLY (plan only). The plan is rederived from the approved simplified PRD v1.5 (FR-1 to FR-27, BR-1 to BR-14, AC-1 to AC-48) and the system documents (api/05 to 08, data-model/04 and 05, architecture/07 to 09, session-lifecycle). The UI spec is still on PRD v1.2 (R-30). Every result is `Not run`. No build, test or repository command was run. [v1.1 | 2026-10-31]

In scope: admin backend endpoints (sign-in, sessions, sign out all other phones, orders, settings, cakes, staff, push, new-device e-mail, review account), the admin app on iOS and Android, the contract fixtures, and the effect on Place Order (FR-27, catalog with up to 12 cakes, lead days, minimum cakes, limit). Out of scope: payment, order editing, customer notifications, reports, and the deferred features (backup e-mail, two-code recovery, device list/revoke, Unfinished view, status history screen, multi-filter, push settings, reminders), which are checked only for absence. [v1.1 | 2026-10-31]

Endpoint names come from `docs/system/api` where they exist; the system documents still contain deferred endpoints (R-4), so cases say "request a code", "sign out all other phones" and so on, and the executable tests bind to the real paths. [v1.1 | 2026-10-31]

## Levels and tooling (proposed; forge-dev confirms in the dev guide)

| Level | Id prefix | Tooling | Where tests live |
| ----- | --------- | ------- | ---------------- |
| Backend API and database | TC-B01 to TC-B145 | HTTP-level tests against real PostgreSQL, parallel requests for races, SQL for assertions, fake mail sink, fake push provider, controlled clock | `backend/Tests/qa/` |
| Admin app, both platforms | TC-C01 to TC-C51 | iOS: XCUITest against a stub backend (simulator iOS 17.5+ and 26.x). Android: Compose UI tests (emulator API 26 and 34). Each TC-C case runs on BOTH platforms; results per platform | `ios/qa/`, `android/qa/` |
| Contract fixtures | TC-F01 to TC-F08 | `contracts/fixtures/admin-*.json` decoded by backend, iOS, Android | `contracts/`, each `qa/` |

Real devices only: push delivery through real push services, the phone dialer, Zalo, e-mail deliverability. Everything else runs against fakes. Anything that cannot run here is marked Blocked with the reason. [v1.1 | 2026-10-31]

## Conventions

- Controlled clock: today `D` = 2026-11-02 (Monday, shop time UTC+7) unless a case names a date. The server clock is injectable; device clocks are never used.
- Case types: acceptance, negative, edge, regression, extra. Extra cases say why they exist. Result values: Not run, Pass, Fail, Blocked.
- Fake accounts: owner "Chu Mau" `chu.mau@example.com`; staff A "Nhan Vien A" `nhanvien.a@example.com`, B `nhanvien.b@example.com`, C `nhanvien.c@example.com`; review `review.demo@example.com` (fixed code only in test configuration, never in the repo); unregistered `khong.co@example.com`. Customer phones `+84 900 000 0xx`. Order codes `BT-AAAAAA` style.
- "+11 min" means 11 minutes after the code was sent.

## Environment rules for the executable tests

1. Mail sink: codes and notices go to a test sink when `MAIL_MODE=test`; never to a real mail service. Production configuration refuses `MAIL_MODE=test`. The sink can be set to fail (TC-B42).
2. Push fake: `PUSH_MODE=test` records every push (token, payload) and injects failures. Real APNs and FCM are Blocked here.
3. Proposed limits (BR-4, BR-5, BR-6, BR-11, BR-12) are configuration values; tests read them from configuration.
4. Database: PostgreSQL is required for race and trigger cases (TC-B25, B39, B82 to B84, B110, B114, B121). No PostgreSQL on this host (Place Order precedent): Blocked locally, run in CI.
5. Logs: the run captures server logs so TC-B96 can scan for personal data.
