# Admin Orders Test Plan: Rounds, defects, verdict, questions, change log (part 09)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.1). Holds: sections 6 Rounds, 7 Defects, 8 Verdict, 9 Open Questions, Change log. [v1.1 | 2026-10-31]

## 6. Rounds

| Round | Date | Build / commit | Pass | Fail | Blocked | Not run |
| ----- | ---- | -------------- | ---- | ---- | ------- | ------- |
| 0 (plan, v1.1) | 2026-10-31 | none (no admin code) | 0 | 0 | 0 | 204 |

## 7. Defects

None. No code exists. Findings against documents are in [part 08](08-review-findings.md) (R-n), not defects. Defects get ids D-n when execute mode starts and are routed `dev` or `requirements`.

## 8. Verdict

Not issued (early mode). Rule for later rounds: Pass only when all 47 Must ACs pass and no high-severity defect is open. The only Should AC is AC-19. The first execute round needs the items E-1 to E-14 in [part 07](07-fixtures-dev-needs.md).

## 9. Open Questions

| ID | Question | Why it matters | Blocking | Class | Owner | Status |
| -- | -------- | -------------- | -------- | ----- | ----- | ------ |
| QT-1 | R-3: is the owner address allowed to be unavailable for an hour through the 3-requests rule | Availability of the one powerful account | No | business | requirements | Open |
| QT-2 | R-1, R-2, R-7: open orders older than 90 days (default list, search, retry of a lost reply, `view=unfinished`) | AC-22 cannot be bound to api/06 as written | Yes | technical | architect, requirements | Open |
| QT-3 | R-5: four or five cancel reasons (`day_full`) | AC-28 and api/design disagree | Yes | technical | architect, design | Open |
| QT-4 | R-4, R-8, R-10: bring api, data-model, auth.md and architecture to PRD v1.5 | Deferred endpoints still specified | Yes | technical | architect | Open |
| QT-5 | R-30 to R-34: reissue the UI spec for PRD v1.5 | No texts or ids for new screens | Yes | technical | design | Open |
| QT-6 | R-9: remove PROPOSAL labels from the approved PRD | Must/Should status of FR-4, AC-7 | No | technical | requirements | Open |
| QT-7 | R-11, R-12, R-13, R-15, R-16: small rule gaps | Boundary cases without expected value | No | technical | requirements, architect | Open |
| QT-8 | E-1 to E-14 delivered by forge-dev | Tests cannot be bound | Yes | technical | forge-dev | Open |

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version (early mode): 197 cases on PRD v1.2. |
| 1.1 | 2026-10-31 | Reworked for PRD v1.5 (27 FR, 14 BR, 48 AC): 204 cases (145 backend, 51 client, 8 fixture). Deleted cases for deferred features; added sign out all other phones, To do list with red marks and badge, four cancel reasons and `fake_spam` limit, void code without lock, new-device mail to the owner only, review account. Findings rewritten (R-1 to R-17, R-30 to R-34, R-40 to R-42). |
