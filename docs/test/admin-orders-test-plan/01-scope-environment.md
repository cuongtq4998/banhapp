# Admin Orders Test Plan: Scope and Environment (part 01)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.0). Holds: section 1 Scope & Environment, case id scheme, fake data. [v2.0 | 2026-11-01]

## 1. Scope & Environment

Mode: EXECUTE, round 1, on commit 6852302 (`feature/admin-orders`): backend slices B1 to B7 (sign-in, orders, status, owner settings, districts and slots, staff, cakes with pictures, push) and `/me` with the caller's e-mail, iOS and Android admin apps parts 1 and 2, UI spec v1.3, system documents aligned in stages 10 to 15. Based on PRD v1.6 (ids as v1.5: FR-1 to FR-27, BR-1 to BR-14, AC-1 to AC-48), `docs/design/admin-orders-ui.md` v1.3, `docs/system/api/05` to `08`, `architecture/07` to `10`, `data-model/04`, `05`, `auth.md`, ADR-0022 to ADR-0031. [v2.0 | 2026-11-01]

In scope: all admin endpoints, the effect on Place Order (FR-27, 12 cakes, lead days, minimum cakes, limit), the two admin apps (through the orchestrator's runs), contract fixtures. Out of scope: payment, order editing, customer notifications, reports, and the deferred features, which are checked only for absence. Details of the environment and of what ran: [part 11](11-execution-backend.md) (backend) and [part 12](12-client-verification.md) (clients). [v2.0 | 2026-11-01]

Real endpoint names (the early plan used neutral words): `POST /v1/auth/code-requests`, `POST /v1/auth/sessions`, `POST /v1/auth/refresh`, `GET /v1/admin/me`, `DELETE /v1/admin/session`, `DELETE /v1/admin/sessions/others`, `PUT /v1/admin/push-token`, `GET /v1/admin/orders` (+ `/{order_code}`, `POST .../status`), `/v1/owner/settings`, `/settings/shop`, `/settings/ordering` (+ `/impact`), `/districts`, `/slots`, `/cakes`, `/staff`, `GET /assets/cakes/{id}`. [v2.0 | 2026-11-01]

## Levels and tooling (as built)

| Level | Id prefix | Tooling | Where tests live |
| ----- | --------- | ------- | ---------------- |
| Backend, developer tests | (named in part 02) | XCTVapor with a real PostgreSQL, injected clock, recording mail and push senders | `backend/Tests/AppTests` |
| Backend, black box | TC-B | Real application on a loopback port, URLSession and a raw socket, PostgreSQL for seeding and assertions, log capture | `backend/Tests/qa/Tests/QATests/Admin/` |
| Admin apps | TC-C | iOS: Swift Testing and XCUITest with a stub backend. Android: JVM tests and Compose tests with fake APIs | `ios/BanhAdminTests`, `ios/BanhAdminUITests`, `android/admin/src/test`, `android/admin/src/androidTest` (developers' own; probe-qa wrote none, `ios/qa` and `android/qa` do not exist) |
| Contract fixtures | TC-F | `contracts/fixtures/admin/*.json`, `contracts/swift` | backend, both apps |

## Conventions

- Case types: acceptance, negative, edge, regression, extra. Results: Pass, Fail, Blocked, Not run, manual/unverified.
- Fake data only: owner "Chu Mau", staff "Nhan Vien A/B/C", `@example.com` addresses, phones `+84 900 000 0xx`, codes `BT-XXXXXX`. QA tests create their own random shop, accounts and addresses per test; unknown addresses are random per run (code rows of unknown addresses are kept per address across shops and clocks).
- Clock: tests that move time use a random far-future day (no collision between runs); the per-phone limit, the 90-day window and the performance tests compare stored `created_at` (database clock) with the app clock, so they use the real time.
- Log level: tests capture the server log at `info` (the deployment default, `LOG_LEVEL`); one test captures `debug`.
- Throwaway databases only (`qa_admin_<n>`); the shared database `banh` is never used.
