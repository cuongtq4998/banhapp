# Admin Orders Test Plan: Rounds, defects, verdict, questions, change log (part 09)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.0). Holds: sections 6 Rounds, 7 Defects, 8 Verdict, 9 Open Questions, Change log. [v1.0 | 2026-10-31]

## 6. Rounds

| Round | Date | Build / commit | Pass | Fail | Blocked | Not run |
| ----- | ---- | -------------- | ---- | ---- | ------- | ------- |
| 0 (plan) | 2026-10-31 | none (no admin code) | 0 | 0 | 0 | 197 |

## 7. Defects

None. No code exists. Findings against documents are in [part 08](08-review-findings.md) (R-n), not defects. Defects get ids D-n when execute mode starts and are routed `dev` or `requirements`.

## 8. Verdict

Not issued (early mode). Rule for later rounds: Pass only when all 66 Must ACs pass and no high-severity defect is open. The Should ACs are AC-19, 25, 31, 47, 50, 51. The first execute round needs the items E-1 to E-14 in [part 07](07-fixtures-dev-needs.md).

## 9. Open Questions

Questions for the orchestrator to route (none go to the owner unless `requirements` decides it is a business choice). Answers needed before the first execute round are marked Blocking.

| ID | Question | Why it matters | Blocking | Class | Owner | Status |
| -- | -------- | -------------- | -------- | ----- | ----- | ------ |
| QT-1 | R-3: may an outsider lock the owner out with wrong codes or code requests? Should the lock apply per client plus address, and should recovery stay available | Availability of the one powerful account; security rule choice | Yes | business | requirements (owner if rule changes) | Open |
| QT-2 | R-5, R-4: inclusive or exclusive limits and lock behaviour (list in the findings) | Boundary cases have no expected value | No | technical | requirements | Open |
| QT-3 | R-8, R-12: repeat of the same status change and renewal request: success (idempotent) or refusal | Double tap and lost response are common on phones | Yes | technical | architect | Open |
| QT-4 | R-16: image size unit, HEIC handling, body limit per route | Upload tests cannot be written | Yes | technical | architect | Open |
| QT-5 | R-10, R-25, R-24: update `auth.md`, place-order PRD/design for FR-44, 12 cakes, e-mail sign-in | Documents contradict the approved PRD | No | technical | architect, requirements | Open |
| QT-6 | R-20: how does the app offer recovery without revealing the owner address | Contradiction FR-1 and AC-59 | Yes | technical | requirements, design | Open |
| QT-7 | R-2: what happens to Confirmed orders older than 90 days | Orders that nobody can finish | No | business | requirements | Open |
| QT-8 | R-21, R-9, R-33: priorities (FR-20 vs AC-26), ACs for G-1 and G-2, scope of FR-30 | Verdict rule uses Must/Should | No | technical | requirements | Open |
| QT-9 | E-1 to E-14 delivered by forge-dev; admin API and UI documents written | Tests cannot be bound to paths and screens | Yes | technical | architect, design, forge-dev | Open |

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version (early mode): 197 cases (143 backend, 47 client, 7 fixtures), traceability for AC-1 to AC-72, fixtures and developer needs, review findings R-2 to R-34. All results Not run. |
