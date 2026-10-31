# Admin Orders: Test Plan (index)

| Field        | Value |
| ------------ | ----- |
| Version      | 1.0 |
| Last updated | 2026-10-31 |
| Status       | Draft |
| Owner        | probe-qa |
| Based on     | product/admin-orders.md v1.2 (Approved) and its parts 01 to 07; system/auth.md v1.5, order-lifecycle.md, api conventions (Place Order set). No admin design or admin API document exists yet |
| Related      | process/standards/11-test.md; test/place-order-tests.md (format precedent); backend/Tests/qa/, ios/qa/, android/qa/ (future executable tests) |

Early mode: plan only, all results `Not run`. The plan is split into parts of at most 200 lines (project file size rule). Case ids: TC-B (backend), TC-C (iOS and Android, each case on both), TC-F (contract fixtures). [v1.0 | 2026-10-31]

## Table of contents

| Part | Sections | Cases |
| ---- | -------- | ----- |
| [01-scope-environment.md](admin-orders-test-plan/01-scope-environment.md) | 1 Scope & Environment, conventions, environment rules | none |
| [02-traceability-matrix.md](admin-orders-test-plan/02-traceability-matrix.md) | 2 Traceability Matrix AC-1 to AC-72, coverage notes | none |
| [03-cases-backend-auth.md](admin-orders-test-plan/03-cases-backend-auth.md) | 4.1 to 4.4 sign-in, sessions, roles, recovery | TC-B01 to TC-B52 (52) |
| [04-cases-backend-orders.md](admin-orders-test-plan/04-cases-backend-orders.md) | 4.5 to 4.9 list, detail, status, 90 days, push, repeat-order limit | TC-B53 to TC-B100 (48) |
| [05-cases-backend-settings.md](admin-orders-test-plan/05-cases-backend-settings.md) | 4.10 to 4.13 cakes, images, ordering rules, validation, staff | TC-B101 to TC-B143 (43) |
| [06-cases-clients-contracts.md](admin-orders-test-plan/06-cases-clients-contracts.md) | 4.14 to 4.16 iOS and Android, extra client cases, fixtures | TC-C01 to TC-C47 (47), TC-F01 to TC-F07 (7) |
| [07-fixtures-dev-needs.md](admin-orders-test-plan/07-fixtures-dev-needs.md) | 3 Test data, developer needs E-1 to E-14, Blocked items | none |
| [08-review-findings.md](admin-orders-test-plan/08-review-findings.md) | 9.1 Contradictions and gaps, 9.2 untestable items (R-2 to R-34) | none |
| [09-rounds-questions-changelog.md](admin-orders-test-plan/09-rounds-questions-changelog.md) | 6 Rounds, 7 Defects, 8 Verdict, 9 Open Questions, change log | none |

## Totals

197 cases: 143 backend, 47 client (x2 platforms = 94 runs), 7 fixture. By type: 86 acceptance, 27 negative, 7 edge, 1 regression, 76 extra. All 72 ACs and 44 FRs are traced. Current verdict: none (early mode); see part 09.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version, see [part 09](admin-orders-test-plan/09-rounds-questions-changelog.md). |
