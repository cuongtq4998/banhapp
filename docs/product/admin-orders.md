# Admin Orders

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.13 [v1.13 | 2026-11-02]                                             |
| Last updated | 2026-11-02                                                            |
| Status       | v1.13 (2026-11-02): the 7-day reading of BR-15, FR-28, AC-49 (today to today + 7 inclusive, checked on each entry and move) is CONFIRMED by the owner (Q-40); no other change. [v1.13 | 2026-11-02] v1.12 (2026-11-02): Approved (owner answer 2026-11-02): BR-16 (new), BR-17 (new), FR-30 (new), AC-53 and AC-54 (new), and the changed BR-2, BR-11, BR-15, FR-28, FR-29, AC-49, AC-50; the 7-day reading of BR-15, FR-28, AC-49 is "to confirm" (Q-40). Customer order tracking (owner answer 4) is a DRAFT part of Place Order (v1.9, part 08), pending owner approval. [v1.12 | 2026-11-02] Earlier, v1.11 (2026-11-02): APPROVED by the owner on 2026-11-02 (explicit answer), every id below that was pending in v1.10; Q-37 and Q-38 answered (expected date drives the due marks, badge and list order when set; moving it does not move the daily limit); Q-35 and Q-36 stay Assumed, to confirm. [v1.11 | 2026-11-02] Approved (2026-11-02) ids: Admin Orders BR-2, BR-8, BR-9, BR-11, BR-15 (new), FR-9, FR-10, FR-13, FR-14, FR-16 to FR-19, FR-23, FR-28 (new), FR-29 (new), AC-26 to AC-29, AC-37, AC-40, AC-41, AC-49 to AC-52 (new); Place Order BR-3, BR-5, BR-9, FR-9, AC-11, AC-14, AC-28. Assumptions Q-35, Q-36 are not yet confirmed (non-blocking). All other ids stay Approved. [v1.11 | 2026-11-02] Earlier status (v1.10): the owner answers on the fee and the six-step process were applied and these ids were pending. Earlier status: Approved. The owner accepted the simplification proposals P-1 to P-4 (Q-25 to Q-28) on 2026-10-31 (v1.6). v1.7 only clarifies wording to match the built system (new-device notice, labels). v1.9 (2026-11-02) records the owner input on the delivery fee and the five-step order process: it conflicts with earlier decisions (09 section 16.2) and Q-30 to Q-36 are open, so BR-2, BR-8, BR-11, FR-16 to FR-18 and AC-26 to AC-29, AC-40, AC-41 stayed as written until answered (answered and rewritten in v1.10); Q-29 is answered. [v1.9 | 2026-11-02] Earlier: one non-blocking business question was open: Q-29 (free delivery). v1.8 closes technical questions TQ-5 to TQ-8, TQ-11 to TQ-13; TQ-1, TQ-2 and TQ-3 stay open (real e-mail delivery, store delivery and fees, live push). [v1.8 | 2026-11-01] |
| Owner        | scribe-requirements                                                   |
| Based on     | docs/pipeline/admin-orders/00-request.md (2026-10-31); docs/product/place-order.md v1.6 |
| Related      | docs/system/order-lifecycle.md; docs/system/auth.md; docs/system/data-model.md; docs/design/reference/screens/ (A1 to A4, reference only) |

This document is split into parts of at most 200 lines each. Cite ids (FR-n, BR-n, AC-n, Q-n) as written in v1.7 (same as v1.5; v1.7 adds only Q-29). [v1.7 | 2026-11-01] Ids of v1.0 to v1.4 are mapped to v1.5 in [08-deferred-and-id-mapping.md](admin-orders/08-deferred-and-id-mapping.md) section 15, so designs, system documents and tests written against v1.4 can follow. Lines changed in v1.5 end with [v1.5 | 2026-10-31]. [v1.5 | 2026-10-31]

## Parts

| Part | Sections | Ids held |
| ---- | -------- | -------- |
| [01-overview.md](admin-orders/01-overview.md) | 0 How a day works (staff, owner, customer), 1 Summary, 2 Background, 3 Goals and non-goals, 4 Users, D-1, D-2 | G-1 to G-4, D-1, D-2 [v1.5 | 2026-10-31] |
| [02-functional-requirements.md](admin-orders/02-functional-requirements.md) | 5 Functional Requirements | FR-1 to FR-30 [v1.12 | 2026-11-02] |
| [03-business-rules.md](admin-orders/03-business-rules.md) | 6 Business Rules | BR-1 to BR-17 [v1.12 | 2026-11-02] |
| [04-acceptance-criteria-sign-in-orders.md](admin-orders/04-acceptance-criteria-sign-in-orders.md) | 7 Acceptance Criteria: sign-in, list, detail | AC-1 to AC-31 [v1.5 | 2026-10-31] |
| [05-acceptance-criteria-settings-notifications.md](admin-orders/05-acceptance-criteria-settings-notifications.md) | 7 Acceptance Criteria: settings, notifications, privacy, cross-feature | AC-32 to AC-54 [v1.12 | 2026-11-02] |
| [06-nfr-dependencies-assumptions-sources.md](admin-orders/06-nfr-dependencies-assumptions-sources.md) | 8 Non-functional, 9 Impact, 10 Assumptions, 11 Sources | A-1 to A-11, S-2 to S-6 |
| [07-open-questions.md](admin-orders/07-open-questions.md) | 12 Open Questions, 13 Change log | Q-1 to Q-41, TQ-1 to TQ-13 [v1.12 | 2026-11-02] |
| [09-order-process-and-delivery-fee.md](admin-orders/09-order-process-and-delivery-fee.md) | 16 Owner input of 2026-11-02: five-step process, delivery fee known at delivery start, conflicts, impact | OD-1 to OD-3, C-1 to C-8 (resolved), Q-30 to Q-38 [v1.10 | 2026-11-02] |
| [08-deferred-and-id-mapping.md](admin-orders/08-deferred-and-id-mapping.md) | 14 Deferred, 15 Mapping of v1.4 ids to v1.5 ids | P-1 to P-4, D-3 to D-8 [v1.5 | 2026-10-31] |

## Summary of v1.5

The owner asked that the admin app and the other apps be easy to understand for every kind of user and not complicated for real daily work. Every rule was checked against the day of a staff member (sign in, see new orders, call, confirm, complete or cancel, look at unfinished orders) and of the owner (change a cake, the daily limit). Rules users would not notice were made invisible or merged; a few features were deferred. Counts: FRs 52 to 27, BRs 28 to 14, ACs 103 to 48. [v1.5 | 2026-10-31]

Four proposals changed explicit owner decisions and were accepted by the owner on 2026-10-31 (07, Q-25 to Q-28): drop backup e-mail and two-code recovery (operator helps instead), replace the device list by "Sign out all other phones", keep only the badge and red marks in the one list instead of a separate Unfinished view, chip and banner, and four cancel reasons instead of five. All other owner decisions (Q-1 to Q-24) are kept. [v1.6 | 2026-10-31]
