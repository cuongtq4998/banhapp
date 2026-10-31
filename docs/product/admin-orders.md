# Admin Orders

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.0                                                                   |
| Last updated | 2026-10-31                                                            |
| Status       | Draft                                                                 |
| Owner        | scribe-requirements                                                   |
| Based on     | docs/pipeline/admin-orders/00-request.md (2026-10-31); docs/product/place-order.md v1.5 |
| Related      | docs/system/order-lifecycle.md; docs/system/auth.md; docs/system/data-model.md; docs/design/reference/screens/ (A1 to A4, ios and android, reference only) |

This document is split into parts of at most 200 lines each (project file size rule). Cite ids (FR-n, BR-n, AC-n, Q-n) as written.

## Parts

| Part | Sections | Ids held |
| ---- | -------- | -------- |
| [01-overview.md](admin-orders/01-overview.md) | 1 Summary, 2 Background & Problem, 3 Goals / Non-goals, 4 Users & Scenarios, recommendations on the two open decisions | G-1 to G-4, D-1, D-2 |
| [02-functional-requirements.md](admin-orders/02-functional-requirements.md) | 5 Functional Requirements | FR-1 to FR-35 |
| [03-business-rules.md](admin-orders/03-business-rules.md) | 6 Business Rules | BR-1 to BR-15 |
| [04-acceptance-criteria-sign-in-orders.md](admin-orders/04-acceptance-criteria-sign-in-orders.md) | 7 Acceptance Criteria: sign-in, list, detail | AC-1 to AC-30 |
| [05-acceptance-criteria-settings-notifications.md](admin-orders/05-acceptance-criteria-settings-notifications.md) | 7 Acceptance Criteria: settings, notifications, general | AC-31 to AC-52 |
| [06-nfr-dependencies-assumptions-sources.md](admin-orders/06-nfr-dependencies-assumptions-sources.md) | 8 Non-functional, 9 Impact & Dependencies, 10 Assumptions, 11 Research & Sources | A-1 to A-10, S-1 to S-4 |
| [07-open-questions.md](admin-orders/07-open-questions.md) | 12 Open Questions (one batch), 13 Change log | Q-1 to Q-14, TQ-1 to TQ-5 |

## Status note

Draft. Three blocking business questions (Q-1 shape of the admin app, Q-2 platform, Q-3 cost of text-message codes) must be answered before approval. All other questions have a recommended default that applies if the owner does not object.
