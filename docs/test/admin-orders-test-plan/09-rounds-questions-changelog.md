# Admin Orders Test Plan: Rounds, defects, verdict, questions, change log (part 09)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.0). Holds: sections 6 Rounds, 7 Defects, 8 Verdict, 9 Open Questions, Change log. Defect details (steps, expected, actual) are in [admin-orders-defects.md](../admin-orders-defects.md). [v2.0 | 2026-11-01]

## 6. Rounds

| Round | Date | Build / commit | Pass | Fail | Blocked / manual |
| ----- | ---- | -------------- | ---- | ---- | ---------------- |
| 0 (plan v1.1, early) | 2026-10-31 | none | 0 | 0 | 204 not run |
| 1 backend (developer tests) | 2026-11-01 | 6852302 | 575 | 0 | 0 |
| 1 contracts | 2026-11-01 | 6852302 | 26 | 0 | 0 |
| 1 QA package before repair | 2026-11-01 | 6852302 | 175 | 2 tests (18 failure messages: 17 README check, 1 runner error) | 0 |
| 1 QA package after repair and 53 new tests | 2026-11-01 | 6852302 | 230 | 0 | 0 |
| 1 clients (orchestrator's runs, not re-run) | 2026-11-01 | 6852302 | iOS 93 + 55 + 9 + 201; Android 117 + 64 + 184 | 0 | see part 12 |

Acceptance criteria: 47 Must/Should ACs have passing automated evidence for the part that can run here (some with gaps, part 10); AC-13 (Must) fails; AC-25, AC-30, AC-31 rest on manual checks. [v2.0 | 2026-11-01]

## 7. Defects (round 1)

| ID | Severity | Component | Summary | Route | Status |
| -- | -------- | --------- | ------- | ----- | ------ |
| D-1 | Medium | backend | AC-13 / FR-8: review account (fixed code, 3 demo orders) not implemented | dev (forge-dev), or owner decision to defer via requirements | Open |
| D-2 | Medium | backend, Android, iOS | Push never ran on a real service: live APNs and FCM clients unverified; Android build has no FCM service (`src/pushFcm` absent, push off); AC-42 to 44 unproven on devices | dev (forge-dev) plus orchestrator (credentials, owner money decision for Apple) | Open, external dependency |
| D-3 | Low | backend | Cancel of an order whose `day_load` row holds fewer cakes than the order answers 500 `INTERNAL_ERROR` (safe: nothing changes) | dev | Open |
| D-4 | Low | backend, deployment docs | `LOG_LEVEL=debug` or `trace` writes customer names, phones, e-mail addresses and Authorization headers to the log | dev (cap or warn) and architect (document) | Open |
| X-1 to X-4 | Doc | PRD, UI, system docs | Inconsistencies for scribe, see the defect file | requirements | Open |

No high-severity defect is open. The 18 failures of the old QA run were test and harness faults, repaired in the QA package (not code defects). [v2.0 | 2026-11-01]

## 8. Verdict (round 1, commit 6852302)

Backend and contracts: Pass with D-1 open. Whole feature: CONDITIONAL, not an unconditional Pass, because the rule says Pass only when all Must ACs pass: AC-13 fails (D-1), and AC-42 to 44 and AC-25 are proven only against fakes or not at all (D-2, G-2, G-3). No high-severity defect and no wrong behaviour was found in the built server: 230 black-box and 575 developer backend tests pass, race and abuse cases hold, performance has a wide margin. Go for the pull request on these conditions: (1) the owner or the orchestrator decides D-1 (implement the review account, or record that AC-13 is deferred until the store review, through scribe); (2) the pull request text states that push is verified against fakes only and that Android push needs a Firebase project, iOS push an Apple Developer account (D-2); (3) one manual smoke run of an admin app against a local backend and a manual pass on VoiceOver/TalkBack, Dynamic Type, dialer/Zalo before real use (part 12); (4) D-3 and D-4 may follow after the pull request. [v2.0 | 2026-11-01]

## 9. Open Questions (for the orchestrator)

| ID | Question | Why it matters | Blocking | Class | Owner | Status |
| -- | -------- | -------------- | -------- | ----- | ----- | ------ |
| QT-1 | R-3 / O-2: accept that an outsider can block the owner's code requests for an hour with 3 requests | Availability of the one powerful account; operator recovery exists (A-7) | No | business | scribe, owner | Open (accepted by design) |
| QT-2 | D-1: implement the review account now or defer AC-13 | Must AC fails; store review is not scheduled | Yes for an unconditional Pass | business | owner via scribe | Open |
| QT-3 | D-2: who creates the Firebase project and the Apple push key, and when | AC-42 to 44 cannot be proven without them | No for the pull request, yes for go-live | money | owner | Open |
| QT-4 | R-17: an old Confirmed order can be completed once and not corrected | Possible owner expectation | No | business | scribe | Open |
| QT-5 | Should the 99+ text, Android staff-hides-Settings and the pull-down gesture get UI tests | Small gaps G-6 to G-8 | No | technical | forge-dev | Open |

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version (early mode): 197 cases on PRD v1.2. |
| 1.1 | 2026-10-31 | Reworked for PRD v1.5 (27 FR, 14 BR, 48 AC): 204 cases. |
| 2.0 | 2026-11-01 | Execute mode, round 1 on 6852302: plan aligned to the built system (TC-B57, B60, B67, B68, B115, B116 rewritten; search minimum 3; field codes of api/08 11.1; D-1/D-2 fixes; push; /me e-mail). Parts 02 (AC to evidence), 10 (FR matrix, gaps), 11 (backend execution), 12 (client evidence) and the defect file added. 53 new QA tests; 18 old QA failures repaired in the tests. |
