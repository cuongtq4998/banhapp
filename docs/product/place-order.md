# Place Order

| Field        | Value                                                        |
| ------------ | ------------------------------------------------------------ |
| Version      | 1.10 [v1.10 | 2026-11-02]                                    |
| Last updated | 2026-11-02                                                   |
| Status       | v1.10: part 08 updated with the owner answers of 2026-11-02 (phone-only lookup, no push, minimum data; new AC-48, 14.7); still DRAFT, pending owner approval after reading. [v1.10 | 2026-11-02] v1.9: new part 08 (order tracking, FR-22 to FR-27, BR-15 to BR-18, AC-38 to AC-47, Q-O6 to Q-O12) is DRAFT, pending owner approval; every other id keeps its status. [v1.9 | 2026-11-02] v1.8: BR-3, BR-5, BR-9, FR-9, AC-11, AC-14, AC-28 Approved (2026-11-02) by the owner (explicit answer); all other ids stay Approved. [v1.8 | 2026-11-02] Earlier (v1.7): these ids were pending owner approval. Earlier: Approved [v1.2 | 2026-10-25]. v1.3 clarifies wording only; no owner-decided number or rule changed. Items under "Added in v1.3, pending owner confirmation" (12.2) do not take effect until the owner confirms; FR-20 and FR-21 were confirmed on 2026-10-29 (v1.5), Q-O1 to Q-O5 remain pending. [v1.5 | 2026-10-29] v1.4 records the owner decision of 2026-10-26 on fewer than four active cakes (Q-15) and clarifies AC-29 (DOC-6). [v1.4 | 2026-10-26] |
| Owner        | scribe-requirements                                          |
| Based on     | docs/pipeline/place-order/00-request.md (2026-10-25)         |
| Related      | UI mockups (reference only): https://claude.ai/artifact/HcWoUjBbqA9B1WUvZ3RKCb |

This document is split into parts of at most 200 lines each (project file size rule). Section numbers and ids are unchanged from v1.4; cite ids (FR-n, BR-n, AC-n and so on) as before. Version 1.4.1 is a structural change only. [v1.4.1 | 2026-10-27]

## Parts

| Part | Sections | Ids held |
| ---- | -------- | -------- |
| [01-overview.md](place-order/01-overview.md) | 1 Summary, 2 Background & Problem, 3 Goals / Non-goals, 4 Users & Scenarios | G-1 to G-3 |
| [02-functional-requirements.md](place-order/02-functional-requirements.md) | 5 Functional Requirements | FR-1 to FR-21 |
| [03-business-rules.md](place-order/03-business-rules.md) | 6 Business Rules | BR-1 to BR-14 [v1.6 | 2026-10-31] |
| [04-acceptance-criteria.md](place-order/04-acceptance-criteria.md) | 7 Acceptance Criteria | AC-1 to AC-37 [v1.6 | 2026-10-31] |
| [05-nfr-dependencies-assumptions-sources.md](place-order/05-nfr-dependencies-assumptions-sources.md) | 8 Non-functional, 9 Impact & Dependencies, 10 Assumptions, 11 Research & Sources | A-1 to A-9, S-1 to S-3 |
| [06-open-questions.md](place-order/06-open-questions.md) | 12 Open Questions, 12.1 Launch data, 12.2 Pending owner confirmation | Q-1 to Q-15, Q-T1 to Q-T6, Q-O1 to Q-O5, N-1, N-2 |
| [07-change-log.md](place-order/07-change-log.md) | 13 Change log | versions 1.0 to 1.9 [v1.9 | 2026-11-02] |
| [08-order-tracking.md](place-order/08-order-tracking.md) | 14 Order tracking in the customer app (Draft) | FR-22 to FR-27, BR-15 to BR-18, AC-38 to AC-48, Q-O6 to Q-O12, 14.7 security [v1.10 | 2026-11-02] |

v1.6 [v1.6 | 2026-10-31]: owner decision Q-12 of Admin Orders applied (Q-O3 answered, new BR-14 and AC-35 to AC-37) and the catalog may hold up to 12 cakes (Admin Orders Q-17; FR-3, BR-13, AC-4, overview). Q-O4 stays open by owner decision.
