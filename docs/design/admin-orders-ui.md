# Admin Orders: UI Specification (index)

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.1 [v1.1 | 2026-10-31]                                              |
| Last updated | 2026-10-31                                                            |
| Status       | Draft                                                                 |
| Owner        | canvas-ui                                                             |
| Based on     | product/admin-orders.md v1.6 (simplified text of v1.5, approved by the owner 2026-10-31) [v1.1 | 2026-10-31] |
| Related      | design/design-system.md v1.6 (part 7 for the admin app); design/place-order-ui.md (Customer app); design/reference/ (board screens A1 to A4, reference only); docs/system/auth.md; docs/system/order-lifecycle.md |

This specification is split into parts of at most 200 lines each (project file size rule). This file is the index. Section numbers follow standard 02. Screen IDs use the prefix `S-A` (admin) to stay apart from the Customer app `S-1` to `S-9`. IDs were renumbered in v1.1 (20 screens became 13); the mapping to the v1.0 ids is in part 1, section 5.1. [v1.1 | 2026-10-31]

## 1. Header and parts

| Part | File | Sections |
| ---- | ---- | -------- |
| 1 | [Overview, research, flows, "how a day works", screen inventory and id mapping](admin-orders/01-overview-research-flow.md) | 2, 3, 4, 4.1, 5 |
| 2 | [Common layout, sign-in, code (S-A1, S-A2)](admin-orders/02-screens-sign-in.md) | 5 |
| 3 | [Order list, order detail, cancel (S-A3 to S-A5)](admin-orders/03-screens-orders.md) | 5 |
| 4 | [Settings home, ordering, delivery, shop info (S-A6, S-A9 to S-A11)](admin-orders/04-screens-settings.md) | 5 |
| 5 | [Cakes: list, cake form (S-A7, S-A8)](admin-orders/05-screens-cakes.md) | 5 |
| 6 | [Staff, account sheet (S-A12, S-A13)](admin-orders/06-screens-accounts.md) | 5 |
| 7 | [Notifications, shared patterns, platform notes, motion and haptics](admin-orders/07-notifications-platform-motion.md) | 6, 6.1, 7 |
| 8 | [Copy: common, sign-in, orders](admin-orders/08-copy-common-orders.md) | 8.1 to 8.3 |
| 9 | [Copy: settings, cakes, staff, notifications](admin-orders/09-copy-settings-accounts.md) | 8.4 to 8.7 |
| 10 | [Accessibility, test identifiers](admin-orders/10-accessibility-test-ids.md) | 9, 9.1 |
| 11 | [Traceability (FR and AC), assets, open questions, change log](admin-orders/11-traceability-questions-changelog.md) | 10, 11, 12 |

Quick finds: copy keys (`A_*`) in parts 8 and 9 (deleted keys are listed at the top of each); test identifiers (`admin.*`) in part 10; questions Q-D and TQ-D in part 11; tokens and components in [design-system part 7](design-system/07-admin-additions.md).

Ready gate status: every FR and AC of the PRD with UI impact is traced (part 11); every screen lists the six states or "N/A" with a reason; no blocking question is open (Q-D3 to Q-D5 and TQ-D1 to TQ-D8 are non-blocking, with a proposal in each). [v1.1 | 2026-10-31]

## Change log (index)

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.1 | 2026-10-31 | Simplified to PRD v1.6: 13 screens (was 20), flows per user type, deleted unused copy keys and test identifiers. See part 11. |
| 1.0 | 2026-10-31 | First version: 20 screens for the Admin app on iOS and Android, based on PRD v1.2. |
