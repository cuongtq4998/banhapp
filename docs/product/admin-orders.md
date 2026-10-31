# Admin Orders

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.4 [v1.4 | 2026-10-31]                                               |
| Last updated | 2026-10-31                                                            |
| Status       | Approved (owner approval of v1.2, 2026-10-31). v1.3 recorded owner decisions and closed review findings. v1.4 records Q-20, Q-22 (changed: Unfinished view) and Q-24 (new-device notice); only Q-23 (daily reminder push, default none) is open and does not block [v1.4 | 2026-10-31] |
| Owner        | scribe-requirements                                                   |
| Based on     | docs/pipeline/admin-orders/00-request.md (2026-10-31); docs/product/place-order.md v1.5 |
| Related      | docs/system/order-lifecycle.md; docs/system/auth.md; docs/system/data-model.md; docs/design/reference/screens/ (A1 to A4, ios and android, reference only) |

This document is split into parts of at most 200 lines each (project file size rule). Cite ids (FR-n, BR-n, AC-n, Q-n) as written. Lines changed in v1.1 end with [v1.1 | 2026-10-31]; lines changed in v1.2 end with [v1.2 | 2026-10-31]; lines changed in v1.3 end with [v1.3 | 2026-10-31]; lines changed in v1.4 end with [v1.4 | 2026-10-31].

## Parts

| Part | Sections | Ids held |
| ---- | -------- | -------- |
| [01-overview.md](admin-orders/01-overview.md) | 1 Summary, 2 Background & Problem, 3 Goals / Non-goals, 4 Users & Scenarios, owner decisions D-1 and D-2 | G-1 to G-4, D-1, D-2 |
| [02-functional-requirements.md](admin-orders/02-functional-requirements.md) | 5 Functional Requirements | FR-1 to FR-52 [v1.4 | 2026-10-31] |
| [03-business-rules.md](admin-orders/03-business-rules.md) | 6 Business Rules | BR-1 to BR-28 [v1.4 | 2026-10-31] |
| [04-acceptance-criteria-sign-in-orders.md](admin-orders/04-acceptance-criteria-sign-in-orders.md) | 7 Acceptance Criteria: sign-in, list, detail | AC-1 to AC-30 |
| [05-acceptance-criteria-settings-notifications.md](admin-orders/05-acceptance-criteria-settings-notifications.md) | 7 Acceptance Criteria: settings, notifications, sessions and recovery, cakes and rules, order window and cancel reasons, review findings, new-device notice and unfinished orders | AC-31 to AC-103 [v1.4 | 2026-10-31] |
| [06-nfr-dependencies-assumptions-sources.md](admin-orders/06-nfr-dependencies-assumptions-sources.md) | 8 Non-functional, 9 Impact & Dependencies, 10 Assumptions, 11 Research & Sources | A-1 to A-10, S-1 to S-6 |
| [07-open-questions.md](admin-orders/07-open-questions.md) | 12 Open Questions, 13 Change log | Q-1 to Q-24, TQ-1 to TQ-13 [v1.4 | 2026-10-31] |

## Summary of v1.1

The owner decided Q-1 to Q-14 (all closed). The admin app is separate, built for iOS and Android at the same time, with e-mail plus one-time-code sign-in (no SMS), 7-day sessions, up to 30 staff, add and remove cakes, owner-set daily limit, lead days and minimum cakes, mandatory cancel reasons, a 90-day order window and backup-e-mail recovery for the owner. Counts: 44 FRs (35 before), 21 BRs (15 before), 72 ACs (52 before); every FR has at least one AC. D-1 and D-2 are now decisions. [v1.1 | 2026-10-31]

## Traceability of v1.1 additions

| Decision | FR | BR | AC |
| -------- | -- | -- | -- |
| Q-3 e-mail sign-in | FR-1 to FR-3, FR-27 | BR-5, BR-7 | AC-1 to AC-9, AC-42, AC-43 |
| Q-4 sessions, revoke | FR-4, FR-7, FR-36, FR-37 | BR-6, BR-8 | AC-10, AC-14, AC-53 to AC-56 |
| Q-5 staff limit | FR-27 | BR-8 | AC-43 |
| Q-6 add and remove cakes | FR-22, FR-38, FR-39 | BR-11, BR-18, BR-19 | AC-33, AC-34, AC-60 to AC-63 |
| Q-7 ordering rules | FR-24, FR-40 | BR-9, BR-21 | AC-37, AC-38, AC-64 to AC-66 |
| Q-8 complete any time | FR-17 | BR-2 | AC-27 |
| Q-9 cancel reasons | FR-18, FR-20 | BR-16 | AC-28, AC-29, AC-31, AC-69 |
| Q-12 repeat-order limit | FR-44 | BR-16 | AC-70 to AC-72 |
| Q-13 90-day window | FR-41 | BR-20 | AC-67, AC-68 |
| Q-14 backup e-mail recovery | FR-42, FR-43 | BR-17 | AC-57 to AC-59 |
| Q-20 no time lock (v1.4) | FR-6 | BR-5, BR-17 | AC-8, AC-77, AC-78 |
| Q-22 Unfinished view (v1.4) | FR-41, FR-48 to FR-52 | BR-20, BR-27, BR-28 | AC-83, AC-96 to AC-103 |
| Q-24 new-device notice (v1.4) | FR-47 | BR-26 | AC-94, AC-95 |

## Status note

Approved by the product owner on 2026-10-31. In v1.4 no question blocks; Q-23 (daily reminder push) is open with the default "no push". [v1.4 | 2026-10-31] Q-15 (the 7-day sign-in restarts on each use), Q-16 (two different recovery codes, one per mailbox, both required) and Q-17 (at most 12 cakes, active plus hidden) were decided with the recommended options. Technical questions TQ-1 to TQ-10 remain for the architect. [v1.2 | 2026-10-31]

## Summary of v1.3

Owner decisions recorded (not reopened): ordinary owner sign-in needs one code and the two-code recovery stays as a separate, slower flow (Q-18); the store-review account is a fixed-code staff account that sees only fake demo orders (Q-19); the retention period for customer data stays open (Q-O4, decide later; the 90-day rule is display only); go-live on paid hosting is not approved, free tier first (Q-21); access and refresh credentials as in ADR-0022 with a 20-second grace window (TQ-4). The review findings R-2 to R-34 owned by requirements are closed with rules and acceptance criteria: lockout (BR-5, BR-17), exact boundaries (BR-23), repeat requests (FR-19, FR-36), images (BR-18), formats (BR-25), search (BR-24), reactivation, minimum cakes against the limit, goals G-1 and G-2 (AC-73, AC-74), priorities (FR-45). Counts: 46 FRs (44 before), 25 BRs (21 before), 93 ACs (72 before). The Place Order PRD is updated to v1.6 for FR-44 and up to 12 cakes. [v1.3 | 2026-10-31]
