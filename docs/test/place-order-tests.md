# Place Order: Test Plan and Report (index)

| Field        | Value |
| ------------ | ----- |
| Version      | 1.7 |
| Last updated | 2026-10-27 |
| Status       | Draft |
| Owner        | probe-qa |
| Based on     | product/place-order.md v1.4 [v1.5 | 2026-10-26]; design/place-order-ui.md v1.0; system/api.md v1.6 [v1.5 | 2026-10-26], data-model.md v1.3; ADR-0017 [v1.5 | 2026-10-26]; order-lifecycle.md v1.0, auth.md v1.0, data-model.md v1.0, architecture.md v1.0; ADR-0005, 0008 to 0011, 0013 to 0015 |
| Related      | process/standards/11-test.md; engineering/dev-guide.md (not yet written); backend/Tests/qa/ (executable tests) |

This report was one file of 668 lines (v1.6). Since v1.7 (2026-10-27) it is split into the parts below to follow the 200-line file size rule (CLAUDE.md "Project rule: file size"). Nothing was dropped or renumbered: test case ids (TC-nnn, TC-S1-nn), defect ids (D-nn, DOC-nn), question ids (Q-xxx), section numbers and every verdict are the same as in v1.6. Other documents that cite "section 4.2" or "D-17" of this report keep working: look the section up in the table of contents below. Each part states in its own header the ids it holds.

## Table of contents

| Part | Sections (numbers as in v1.6) | Test cases defined (rows) | Slice 1 plan ids | Defects mentioned |
| ---- | ----------------------------- | ------------------------- | ---------------- | ----------------- |
| [01-scope-matrix-data.md](place-order-tests/01-scope-matrix-data.md) | 1. Scope and Environment, 2. Traceability Matrix, 3. Test data and environment needs | none | none | D-15 to D-20 (2) |
| [02-cases-api.md](place-order-tests/02-cases-api.md) | 4.1 API / backend level | TC-1 to TC-70 (70) | none | none |
| [03-cases-ui.md](place-order-tests/03-cases-ui.md) | 4.2 iOS UI level, 4.3 Android UI level | TC-101 to TC-267 (67) | none | none |
| [04-cases-slice0-slice1.md](place-order-tests/04-cases-slice0-slice1.md) | 4.4 Slice 0 executable tests, 4.5 Slice 1 executable tests (plan cases and extra cases) | TC-55 to TC-98 (36) | TC-S1-01 to TC-S1-29 (29) | D-1 to D-12 (11) |
| [05-slice1-retest-and-verdict-rounds.md](place-order-tests/05-slice1-retest-and-verdict-rounds.md) | 4.7 Slice 1 verdict round 6, 4.6 Slice 1 backend retest round 5, 5. Additional Cases | none | TC-S1-30 to TC-S1-44 (15) | D-15 to D-20 (6) |
| [06-rounds-defects.md](place-order-tests/06-rounds-defects.md) | 6. Rounds, 7. Defects | none | none | D-1 to D-20 (20) |
| [07-verdict.md](place-order-tests/07-verdict.md) | 8. Verdict | none | none | D-1 to D-20 (19) |
| [08-questions-changelog.md](place-order-tests/08-questions-changelog.md) | 9. Open Questions / Change log (9.1 to 9.5) and the Change log table | none | none | D-1 to D-20 (9) |

## Where to find what

| Looking for | Go to |
| ----------- | ----- |
| Scope, environment, commands, seed values (section 1) | [part 01](place-order-tests/01-scope-matrix-data.md) |
| Traceability matrix acceptance criteria to test cases (section 2) | [part 01](place-order-tests/01-scope-matrix-data.md) |
| What developers must provide, E-1 to E-12 (section 3) | [part 01](place-order-tests/01-scope-matrix-data.md) |
| API / backend cases TC-1 to TC-70 (4.1) | [part 02](place-order-tests/02-cases-api.md) |
| iOS cases TC-101 to TC-165 (4.2), Android cases TC-201 to TC-267 (4.3) | [part 03](place-order-tests/03-cases-ui.md) |
| Slice 0 executable tests TC-71 to TC-98 (4.4), slice 1 plan and extra cases TC-S1-01 to TC-S1-29 (4.5) | [part 04](place-order-tests/04-cases-slice0-slice1.md) |
| Slice 1 verdict round 6 (4.7), retest round 5 TC-S1-30 to TC-S1-44 (4.6), additional cases (5) | [part 05](place-order-tests/05-slice1-retest-and-verdict-rounds.md) |
| Rounds (section 6), defects D-1 to D-20 (section 7) | [part 06](place-order-tests/06-rounds-defects.md) |
| Verdict and open gaps (section 8) | [part 07](place-order-tests/07-verdict.md) |
| Open questions Q-S, Q-U, Q-A, Q-P, DOC items (9.1 to 9.5), change log | [part 08](place-order-tests/08-questions-changelog.md) |

## Current verdict (unchanged from v1.6)

See section 8 in [part 07](place-order-tests/07-verdict.md) and section 4.7 in [part 05](place-order-tests/05-slice1-retest-and-verdict-rounds.md). This index does not restate it, so there is one source of truth.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.7 | 2026-10-27 | Split into this index and eight parts under `place-order-tests/`; full change log in [part 08](place-order-tests/08-questions-changelog.md). No content, id or verdict changed. |
