# Design System (index)

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.6 [v1.6 | 2026-10-31]                                                |
| Last updated | 2026-10-31                                                            |
| Status       | Draft                                                                 |
| Owner        | canvas-ui                                                             |
| Based on     | product/place-order.md v1.4 (first consumer); design/reference (owner's design board, visual source of truth) [v1.2 | 2026-10-26] |
| Related      | design/place-order-ui.md; design/reference/README.md                  |

[v1.3 | 2026-10-27] The design system is split into parts of at most 200 lines each (project file size rule). This file is the index and keeps the old path, so existing links keep working. Content is unchanged from v1.2. The original section numbers (1 to 7, 2.1 to 2.8) are kept as headings inside the parts; other documents and code comments cite them as "design-system.md section 2.1" and so on, so use the table below to find the part.

| Part | File | Sections |
| ---- | ---- | -------- |
| 1 | [Principles and sources](design-system/01-principles-sources.md) | 1 |
| 2 | [Color tokens, blob geometry](design-system/02-tokens-color.md) | 2, 2.1 |
| 3 | [Typography, spacing, radius tokens](design-system/03-tokens-type-space-radius.md) | 2.2, 2.3, 2.4 |
| 4 | [Elevation and material, motion tokens, iconography, component styles](design-system/04-tokens-elevation-motion-icons-styles.md) | 2.5, 2.6, 2.7, 2.8 |
| 5 | [Components and glass fallbacks](design-system/05-components.md) | 3 |
| 6 | [Motion and haptics, accessibility, open questions, change log](design-system/06-motion-accessibility-questions.md) | 4, 5, 6, 7 |
| 7 | [Admin app additions: status tokens, new components](design-system/07-admin-additions.md) [v1.6 | 2026-10-31] | 7.1, 7.2, 7.3 |

Quick finds: color tokens in part 2; `type.*` tokens in part 3; `space.*`, `size.*` tokens in part 3; `radius.*` in part 3; `elevation.*` and `material.fallback` in part 4; `motion.*` tokens (2.6) in part 4; the haptics table (section 4) in part 6; `AppBackground`, `TopBar`, `ProductCard` and the other components in part 5; DS-Q questions and the full change log in part 6.

## Change log (index)

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.6 | 2026-10-31 | Admin app simplified (PRD v1.6): part 7 drops `DeviceRow`, `HistoryTimeline`, `BannerAction`; adds `DueMark`, `TabBadge`; `FilterChip` single-select; `ReasonList` four rows. [v1.6 | 2026-10-31] |
| 1.5 | 2026-10-31 | Admin app: new part 7 with status, code and size tokens and 14 components (`StatusBadge`, `OrderRow`, `OtpField`, `AdminTabBar` and others). Parts 1 to 6 unchanged. |
| 1.4 | 2026-10-29 | New component `PrivacyNoticeCard` (part 5); no new tokens. |
| 1.3 | 2026-10-27 | Split into 6 parts under `design-system/` and this index; no change of meaning. The change history of versions 1.0 to 1.2 is in part 6. |
