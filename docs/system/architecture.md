# System Architecture

| Field        | Value |
| ------------ | ----- |
| Version      | 1.13 [v1.13 | 2026-10-31] |
| Last updated | 2026-10-31 |
| Status       | Draft |
| Owner        | atlas-architect |
| Based on     | product/place-order.md v1.2; design/place-order-ui.md v1.0; design/design-system.md v1.0; product/admin-orders.md v1.6 (27 FR, 14 BR) [v1.13 | 2026-10-31] |
| Related      | data-model.md; api.md; order-lifecycle.md; admin-order-handling.md; session-lifecycle.md; auth.md; deployment.md; docs/decisions/; ADR-0017; ADR-0018 to ADR-0020; ADR-0021 to ADR-0031 |

This file is the index of the architecture document. The body lives in the folder `architecture/`, split by topic so that no file passes 200 lines (CLAUDE.md "Project rule: file size"). Section numbers are unchanged: "architecture.md section 11" still means the same text, found through the map below. [v1.8 | 2026-10-27]

## Section map [v1.8 | 2026-10-27]

| Section | Subject | File |
| ------- | ------- | ---- |
| Intro, 1, 2, 3 | Owner decisions, purpose, system context, components | [architecture/01-context-and-components.md](architecture/01-context-and-components.md) |
| 4, 5, 6 | Key flows, data and storage, external integrations | [architecture/02-flows-data-integrations.md](architecture/02-flows-data-integrations.md) |
| 7, 8, 9, 10 | Cross-cutting concerns, quality attributes, constraints, extension points | [architecture/03-cross-cutting-quality.md](architecture/03-cross-cutting-quality.md) |
| 11 | Slice plan | [architecture/04-slice-plan.md](architecture/04-slice-plan.md) |
| 12, 13 | Decision index, risks and open questions | [architecture/05-decisions-and-risks.md](architecture/05-decisions-and-risks.md) |
| 13 (change log) | Version history | this file |
| 14, 14.1 | Backend code structure, `DomainError` | [architecture/06-code-structure.md](architecture/06-code-structure.md) |
| 15 | Client code structure (iOS MVVM-C, Android MVI) | [architecture/06-code-structure.md](architecture/06-code-structure.md) |
| 16 to 22 | Admin apps: scope, context, components, flows, integrations, quality, risks [v1.10 \| 2026-10-31] | [architecture/07-admin-orders.md](architecture/07-admin-orders.md) |
| 24 | Admin technical answers (UI questions TQ-D1 to TQ-D7, QA review items, measurable targets) [v1.11 | 2026-10-31] | [architecture/08-admin-technical-answers.md](architecture/08-admin-technical-answers.md) |
| 25 | Admin simplification, answers to TQ-11 to TQ-13, list of what the PRD v1.6 simplification deleted [v1.13 \| 2026-10-31] | [architecture/09-admin-simplification.md](architecture/09-admin-simplification.md) |

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version. |
| 1.1 | 2026-10-25 | Owner decisions applied: Swift and Vapor, PostgreSQL, free trial hosting, layout, minimum OS, price change. Components, integrations, quality targets, risks updated. Slice plan added (section 11). |
| 1.2 | 2026-10-26 | After slice 0: Android toolchain and CI, application identifiers (ADR-0016), code structure target and refactors before slice 1 (section 14). |
| 1.3 | 2026-10-26 | After the backend refactor round: section 14 matches the built layout (`WallClock`, `DatabasePoolSizing`, `PostgresProbe` in `Repositories/`), error flow, collision retry owner, test target rules, remaining refactors. |
| 1.4 | 2026-10-26 | After backend round 2: `AppServices` holds factories (no probe), `MigrationConfig`, body limit 8 KB + 1, `Retry-After`, `withDeadline` timer and release-check rule, risk R-10, iOS runner corrected to `macos-26`. |
| 1.5 | 2026-10-26 | QA findings and owner decision: the catalog lists every active cake (one to four); static assets folder, versioned image URLs and cache rule (ADR-0017). |
| 1.6 | 2026-10-26 | Section 14: global middleware order, limiter scope and bound, `APIError.headers`, uncached static not-found; `TRUST_PROXY` and `SHOP_ID` needed from slice 1. |
| 1.7 | 2026-10-27 | ADR review: index lists ADR-0017 to ADR-0020 and the amendments; slice plan note for the iOS package extraction; section 14 `DomainError` target and module map pointer. |
| 1.8 | 2026-10-27 | Split into the folder `architecture/` (file size rule, 200 lines); this file became the index with a section map. Owner decisions of 2026-10-27 applied (ADR-0007 v1.5, ADR-0018 v2.0): iOS MVVM-C and Android MVI recorded in new section 15; section 11 note and section 14.1 changed from a calendar of extractions to trigger-only splits, `DomainError` and the layering test confirmed; section 12 index updated. |
| 1.10 | 2026-10-31 | admin-orders: new file 07 (sections 16 to 22): separate admin apps `ios/BanhAdmin*` and `android/admin` with shared packages and modules (ADR-0021, ADR-0018 trigger fired), backend admin feature folders without a new top-level folder, mail, APNs and FCM integrations with failure behaviour, quality targets, risks R-AO-1 to R-AO-8. Decision index extended (ADR-0021 to ADR-0031). Sections 1, 9, 10 statements that staff features are out of scope are superseded by section 16. |
| 1.9 | 2026-10-29 | Slice 3 resync (06 code structure): transaction opened in `OrderRepository.insertOrder`; responses use sorted JSON keys so a replay is byte-identical; ADR-0014 status line. |
| 1.11 | 2026-10-31 | Owner decisions of 2026-10-31 applied (ADR-0022, 0026, 0027 accepted; free tier only, go-live blocked on money; retention still open). New file 08 with the answers to TQ-D1 to TQ-D7 and review items. Slice A6 marked blocked. |
| 1.12 | 2026-10-31 | Aligned with PRD v1.4 and the owner directive to keep things simple: new file 09 (section 25); lock removed, tables 7 to 5, R-7 superseded. |
| 1.13 | 2026-10-31 | PRD v1.6 simplification applied (27 FR, 14 BR): recovery, backup address, device list, Unfinished view, status history screen, push settings and reminder removed from the system documents; "Sign out all other phones" added; one window rule (open orders always listed); four cancel reasons. Section 25.3 is now the record of what was deleted (see 25.5). |
