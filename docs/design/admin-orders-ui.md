# Admin Orders: UI Specification (index)

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.0 [v1.0 | 2026-10-31]                                              |
| Last updated | 2026-10-31                                                            |
| Status       | Draft                                                                 |
| Owner        | canvas-ui                                                             |
| Based on     | product/admin-orders.md v1.2 (Approved 2026-10-31)                    |
| Related      | design/design-system.md v1.5 (part 7 added for the admin app); design/place-order-ui.md (Customer app); design/reference/ (board screens A1 to A4, reference only); docs/system/auth.md; docs/system/order-lifecycle.md |

This specification is split into parts of at most 200 lines each (project file size rule). This file is the index. Section numbers follow standard 02. Screen IDs use the prefix `S-A` (admin) to stay apart from the Customer app `S-1` to `S-9`.

## 1. Header and parts

| Part | File | Sections |
| ---- | ---- | -------- |
| 1 | [Overview, research, flows, screen inventory](admin-orders/01-overview-research-flow.md) | 2, 3, 4, 5 (inventory) |
| 2 | [Common layout, sign-in, code, recovery (S-A1 to S-A3)](admin-orders/02-screens-sign-in.md) | 5 |
| 3 | [Order list, date filter, order detail, cancel (S-A4 to S-A7)](admin-orders/03-screens-orders.md) | 5 |
| 4 | [Settings home, shop info, ordering rules, slots, districts (S-A8 to S-A12)](admin-orders/04-screens-settings.md) | 5 |
| 5 | [Cakes: list, edit, add with image (S-A13 to S-A15)](admin-orders/05-screens-cakes.md) | 5 |
| 6 | [Staff, add staff, devices, account, backup e-mail (S-A16 to S-A20)](admin-orders/06-screens-accounts.md) | 5 |
| 7 | [Notifications, shared patterns, platform notes, motion and haptics](admin-orders/07-notifications-platform-motion.md) | 6, 6.1, 7 |
| 8 | [Copy: common, sign-in, orders](admin-orders/08-copy-common-orders.md) | 8.1 to 8.3 |
| 9 | [Copy: settings, cakes, accounts, notifications](admin-orders/09-copy-settings-accounts.md) | 8.4 to 8.7 |
| 10 | [Accessibility, test identifiers](admin-orders/10-accessibility-test-ids.md) | 9, 9.1 |
| 11 | [Traceability, assets, open questions, change log](admin-orders/11-traceability-questions-changelog.md) | 10, 11, 12 |

Quick finds: copy keys (`A_*`) in parts 8 and 9; test identifiers (`admin.*`) in part 10; questions Q-D and TQ-D in part 11; new tokens and components in [design-system part 7](design-system/07-admin-additions.md).

Ready gate status: every FR with UI impact is traced (part 11); every screen lists the six states or "N/A" with a reason; no blocking question is open (Q-D1 to Q-D4 and TQ-D1 to TQ-D7 are non-blocking, with a proposal in each); copy is final pending Q-D3.

## Change log (index)

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version: 20 screens for the Admin app on iOS and Android, based on PRD v1.2. |
