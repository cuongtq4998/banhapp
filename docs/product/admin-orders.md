# Admin Orders

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.5 [v1.5 | 2026-10-31]                                               |
| Last updated | 2026-10-31                                                            |
| Status       | v1.2 approved by the owner (2026-10-31); v1.3 and v1.4 recorded owner decisions. v1.5 is a simplification PROPOSAL (owner directive 2026-10-31): the parts that change explicit owner decisions (P-1 to P-4, Q-25 to Q-28) wait for the owner; everything else in v1.5 only removes rules users would not notice or makes them invisible. Nothing blocks. [v1.5 | 2026-10-31] |
| Owner        | scribe-requirements                                                   |
| Based on     | docs/pipeline/admin-orders/00-request.md (2026-10-31); docs/product/place-order.md v1.6 |
| Related      | docs/system/order-lifecycle.md; docs/system/auth.md; docs/system/data-model.md; docs/design/reference/screens/ (A1 to A4, reference only) |

This document is split into parts of at most 200 lines each. Cite ids (FR-n, BR-n, AC-n, Q-n) as written in v1.5. Ids of v1.0 to v1.4 are mapped to v1.5 in [08-deferred-and-id-mapping.md](admin-orders/08-deferred-and-id-mapping.md) section 15, so designs, system documents and tests written against v1.4 can follow. Lines changed in v1.5 end with [v1.5 | 2026-10-31]. [v1.5 | 2026-10-31]

## Parts

| Part | Sections | Ids held |
| ---- | -------- | -------- |
| [01-overview.md](admin-orders/01-overview.md) | 0 How a day works (staff, owner, customer), 1 Summary, 2 Background, 3 Goals and non-goals, 4 Users, D-1, D-2 | G-1 to G-4, D-1, D-2 [v1.5 | 2026-10-31] |
| [02-functional-requirements.md](admin-orders/02-functional-requirements.md) | 5 Functional Requirements | FR-1 to FR-27 [v1.5 | 2026-10-31] |
| [03-business-rules.md](admin-orders/03-business-rules.md) | 6 Business Rules | BR-1 to BR-14 [v1.5 | 2026-10-31] |
| [04-acceptance-criteria-sign-in-orders.md](admin-orders/04-acceptance-criteria-sign-in-orders.md) | 7 Acceptance Criteria: sign-in, list, detail | AC-1 to AC-31 [v1.5 | 2026-10-31] |
| [05-acceptance-criteria-settings-notifications.md](admin-orders/05-acceptance-criteria-settings-notifications.md) | 7 Acceptance Criteria: settings, notifications, privacy, cross-feature | AC-32 to AC-48 [v1.5 | 2026-10-31] |
| [06-nfr-dependencies-assumptions-sources.md](admin-orders/06-nfr-dependencies-assumptions-sources.md) | 8 Non-functional, 9 Impact, 10 Assumptions, 11 Sources | A-1 to A-11, S-2 to S-6 |
| [07-open-questions.md](admin-orders/07-open-questions.md) | 12 Open Questions, 13 Change log | Q-1 to Q-28, TQ-1 to TQ-13 [v1.5 | 2026-10-31] |
| [08-deferred-and-id-mapping.md](admin-orders/08-deferred-and-id-mapping.md) | 14 Deferred, 15 Mapping of v1.4 ids to v1.5 ids | P-1 to P-4, D-3 to D-8 [v1.5 | 2026-10-31] |

## Summary of v1.5

The owner asked that the admin app and the other apps be easy to understand for every kind of user and not complicated for real daily work. Every rule was checked against the day of a staff member (sign in, see new orders, call, confirm, complete or cancel, look at unfinished orders) and of the owner (change a cake, the daily limit). Rules users would not notice were made invisible or merged; a few features were deferred. Counts: FRs 52 to 27, BRs 28 to 14, ACs 103 to 48. [v1.5 | 2026-10-31]

Four proposals change explicit owner decisions and are asked in 07 (Q-25 to Q-28): drop backup e-mail and two-code recovery (operator helps instead), replace the device list by "Sign out all other phones", keep only the badge and red marks in the one list instead of a separate Unfinished view, chip and banner, and four cancel reasons instead of five. All other owner decisions (Q-1 to Q-24) are kept. [v1.5 | 2026-10-31]
