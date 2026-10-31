# Admin Orders: Test Plan (index)

| Field        | Value |
| ------------ | ----- |
| Version      | 1.1 |
| Last updated | 2026-10-31 |
| Status       | Draft |
| Owner        | probe-qa |
| Based on     | product/admin-orders.md v1.2 (Approved) and its parts 01 to 07; system/auth.md v1.5, order-lifecycle.md, api conventions (Place Order set). No admin design or admin API document exists yet |
| Related      | process/standards/11-test.md; test/place-order-tests.md (format precedent); backend/Tests/qa/, ios/qa/, android/qa/ (future executable tests) |

Early mode: plan only, all results `Not run`. The plan is split into parts of at most 200 lines (project file size rule). Case ids: TC-B (backend), TC-C (iOS and Android, each case on both), TC-F (contract fixtures). [v1.1 | 2026-10-31]

## Table of contents

| Part | Sections | Cases |
| ---- | -------- | ----- |
| [01-scope-environment.md](admin-orders-test-plan/01-scope-environment.md) | 1 Scope & Environment, conventions | none |
| [02-traceability-matrix.md](admin-orders-test-plan/02-traceability-matrix.md) | 2 Traceability Matrix AC-1 to AC-48, coverage notes | none |
| [03-cases-backend-auth.md](admin-orders-test-plan/03-cases-backend-auth.md) | 4.1 to 4.6 sign-in, sessions, sign out others, roles, staff, new-device mail, review account | TC-B01 to TC-B48 (48) |
| [04-cases-backend-orders.md](admin-orders-test-plan/04-cases-backend-orders.md) | 4.7 to 4.11 To do list, marks, count, status, record, push, limit | TC-B49 to TC-B106 (58) |
| [05-cases-backend-settings.md](admin-orders-test-plan/05-cases-backend-settings.md) | 4.12 to 4.15 cakes, ordering, delivery, shop info, validation | TC-B107 to TC-B145 (39) |
| [06-cases-clients-contracts.md](admin-orders-test-plan/06-cases-clients-contracts.md) | 4.16 to 4.18 iOS and Android, extra, fixtures | TC-C01 to TC-C51 (51), TC-F01 to TC-F08 (8) |
| [07-fixtures-dev-needs.md](admin-orders-test-plan/07-fixtures-dev-needs.md) | 3 Test data (fixtures list), developer needs E-1 to E-14, Blocked | none |
| [08-review-findings.md](admin-orders-test-plan/08-review-findings.md) | 9 Contradictions and gaps (R-n) | none |
| [09-rounds-questions-changelog.md](admin-orders-test-plan/09-rounds-questions-changelog.md) | 6 Rounds, 7 Defects, 8 Verdict, 9 Open Questions, change log | none |

## Totals

204 cases: 145 backend, 51 client (x2 platforms = 102 runs), 8 fixture. By type: 95 acceptance, 32 negative, 6 edge, 1 regression, 70 extra. All 48 ACs and 27 FRs are traced. Current verdict: none (early mode); see part 09. [v1.1 | 2026-10-31]

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version (197 cases, PRD v1.2). |
| 1.1 | 2026-10-31 | Reworked for the simplified PRD v1.5, see [part 09](admin-orders-test-plan/09-rounds-questions-changelog.md). |
