# Admin Orders: Test Plan and Report (index)

| Field        | Value |
| ------------ | ----- |
| Version      | 2.0 |
| Last updated | 2026-11-01 |
| Status       | Round 1 executed on commit 6852302; verdict conditional (part 09) |
| Owner        | probe-qa |
| Based on     | product/admin-orders.md v1.6 (Approved; ids as v1.5) and parts 01 to 08; design/admin-orders-ui.md v1.3; system/api 05 to 08 (api v1.22), architecture 07 to 10, data-model 04 and 05, auth.md, ADR-0022 to ADR-0031; the code of feature/admin-orders at 6852302 |
| Related      | process/standards/11-test.md; test/admin-orders-defects.md; test/place-order-tests.md; backend/Tests/qa/Tests/QATests/Admin/ |

Execute mode. The plan is split into parts of at most 200 lines (project file size rule). Case ids: TC-B (backend), TC-C (clients), TC-F (fixtures). Results are recorded per round with the commit. [v2.0 | 2026-11-01]

## Table of contents

| Part | Sections | Cases |
| ---- | -------- | ----- |
| [01-scope-environment.md](admin-orders-test-plan/01-scope-environment.md) | 1 Scope and environment, conventions | none |
| [02-traceability-matrix.md](admin-orders-test-plan/02-traceability-matrix.md) | 2 AC-1 to AC-48 to named backend, iOS and Android tests | none |
| [03-cases-backend-auth.md](admin-orders-test-plan/03-cases-backend-auth.md) | 4.1 to 4.6 sign-in, sessions, roles, staff, new-device mail, review account | TC-B01 to TC-B48 |
| [04-cases-backend-orders.md](admin-orders-test-plan/04-cases-backend-orders.md) | 4.7 to 4.11 list, search, status, record, push, phone limit | TC-B49 to TC-B106 |
| [05-cases-backend-settings.md](admin-orders-test-plan/05-cases-backend-settings.md) | 4.12 to 4.15 cakes, ordering, delivery, shop info | TC-B107 to TC-B145 |
| [06-cases-clients-contracts.md](admin-orders-test-plan/06-cases-clients-contracts.md) | 4.16 to 4.18 apps, extra, fixtures | TC-C01 to TC-C51, TC-F01 to TC-F08 |
| [07-fixtures-dev-needs.md](admin-orders-test-plan/07-fixtures-dev-needs.md) | 3 Test data, developer needs E-1 to E-14 and their status | none |
| [08-review-findings.md](admin-orders-test-plan/08-review-findings.md) | 9 Document findings R-n and their status after the build | none |
| [09-rounds-questions-changelog.md](admin-orders-test-plan/09-rounds-questions-changelog.md) | 6 Rounds, 7 Defects, 8 Verdict, 9 Questions, change log | none |
| [10-fr-matrix-and-gaps.md](admin-orders-test-plan/10-fr-matrix-and-gaps.md) | FR-1 to FR-27 to evidence; ACs with no automated evidence | none |
| [11-execution-backend.md](admin-orders-test-plan/11-execution-backend.md) | Environment, results, the 18 old failures, QA tests per case, performance, observations | none |
| [12-client-verification.md](admin-orders-test-plan/12-client-verification.md) | iOS and Android evidence and what is not covered | none |

## Totals (round 1, 6852302)

Planned: 204 cases (145 backend, 51 client x 2 platforms, 8 fixture). Executed evidence: backend developer suite 575 pass, contracts 26 pass, QA package 230 pass (53 new in this round), iOS 93 + 55 + 9 + 201 and Android 117 + 64 + 184 pass (orchestrator's runs). Defects: 0 high, 2 medium, 2 low, 4 document items. ACs: 47 of 48 have passing automated evidence (partial gaps in part 10), AC-13 fails. Verdict: conditional go (part 09). [v2.0 | 2026-11-01]

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version (197 cases, PRD v1.2). |
| 1.1 | 2026-10-31 | Reworked for the simplified PRD v1.5. |
| 2.0 | 2026-11-01 | Execute mode, round 1: see [part 09](admin-orders-test-plan/09-rounds-questions-changelog.md). |
