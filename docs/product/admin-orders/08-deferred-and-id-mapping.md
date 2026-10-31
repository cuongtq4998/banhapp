# Admin Orders: Deferred items and id mapping (new in v1.5)

Part of [Admin Orders](../admin-orders.md) (PRD v1.5). Holds: the Deferred list (section 14) and the mapping from v1.4 ids to v1.5 ids (section 15), so designs, system documents and tests can follow. Counts: FR 52 to 27, BR 28 to 14, AC 103 to 48. Every line is new in v1.5 [v1.5 | 2026-10-31].

## 14. Deferred (not in the app scope of this slice)

Rule: a rule stays only if a shop owner or staff member would notice without it, or it is invisible security. Items P-1 to P-4 change explicit owner decisions and need the owner's answer (07, Q-25 to Q-28); until then the v1.5 text is a proposal and the v1.4 text (git history) remains the approved one. The other items were not owner decisions. [v1.5 | 2026-10-31]

| No | Deferred item (old ids) | Reason | Interim |
| -- | ----------------------- | ------ | ------- |
| P-1 | Backup e-mail, two-code owner recovery, recovery notice, backup reminder (FR-42, FR-43, BR-17, AC-57 to AC-59, AC-78; Q-14, Q-16) | Two extra screens, a second mailbox and a second set of limits for a rare case. A lost phone is already solved by one code on a new phone (Q-18) plus P-2. [v1.5 | 2026-10-31] | Operator recovers the owner account outside the app (A-7). Same for a lost owner mailbox. [v1.5 | 2026-10-31] |
| P-2 | Device list with phone names, per-device revoke, owner view of all devices (FR-37, AC-55, AC-56, AC-93 devices part; Q-4, Q-D4) | Needs a screen and reading phone names; the real need is "get rid of the lost phone". [v1.5 | 2026-10-31] | Button "Sign out all other phones" (FR-4); staff removal by switching off. [v1.5 | 2026-10-31] |
| P-3 | Separate Unfinished view, pinned chip, opening banner (FR-48 view, FR-50, FR-51, AC-100 to AC-102, BR-28; Q-22) | The default list already holds every New and Confirmed order of any age, earliest first, so the overdue ones are on top; four ways to the same list teach more than they help. Badge and red marks stay. [v1.5 | 2026-10-31] | Badge plus red marks in the one list (FR-9, FR-13). [v1.5 | 2026-10-31] |
| P-4 | Five cancel reasons (BR-16, AC-69; Q-9) | "Day full" and "cannot deliver" are the same choice for staff; shorter list is faster. Spam rule (Q-12) unchanged. [v1.5 | 2026-10-31] | Four reasons (BR-8). [v1.5 | 2026-10-31] |
| D-3 | Backup-address half of the new-device notice (BR-26, FR-47, AC-94; Q-24) | Follows P-1. The notice itself stays. [v1.5 | 2026-10-31] | Notice goes to the owner e-mail only. [v1.5 | 2026-10-31] |
| D-4 | Status history screen (FR-20 display, AC-31 display) | Nobody asked to read it daily. Recording stays (BR-3). [v1.5 | 2026-10-31] | One line "last changed by" in the detail. [v1.5 | 2026-10-31] |
| D-5 | New-order count and "last updated" time on the list (FR-12 parts, AC-20, AC-21) | The badge and the New filter show it; pull-down refreshes. [v1.5 | 2026-10-31] | None. [v1.5 | 2026-10-31] |
| D-6 | Date range and multi-status filters (FR-9, FR-10) | One status and one date cover the day. [v1.5 | 2026-10-31] | Single choices (FR-10). [v1.5 | 2026-10-31] |
| D-7 | Notification-denied hint and any push settings (FR-34) | The phone's own permission prompt is enough; nothing to configure in the app. [v1.5 | 2026-10-31] | None. [v1.5 | 2026-10-31] |
| D-8 | Reminder push about unfinished orders (FR-52, Q-23) | Withdrawn; Q-11 stands. [v1.5 | 2026-10-31] | Badge only. [v1.5 | 2026-10-31] |

Kept as invisible behaviour (no screen, no learning): code and request limits, 7-day renewal, rotation with 20-second grace, 5-minute cut-off, record of changes, 90-day rule, paging, review account, new-device e-mail. [v1.5 | 2026-10-31]

## 15. Mapping of v1.4 ids to v1.5 ids

### 15.1 Functional requirements

| v1.4 | v1.5 | v1.4 | v1.5 |
| ---- | ---- | ---- | ---- |
| FR-1, FR-2, FR-3 | FR-1 | FR-25 | FR-23 |
| FR-4 | FR-2 | FR-26 | FR-24 |
| FR-5, FR-21 | FR-3, FR-20 | FR-27 | FR-5 |
| FR-6 | FR-1, FR-6 | FR-28, FR-29 | BR-11 |
| FR-7 | FR-5 | FR-30, FR-45 | BR-3 |
| FR-36 | FR-6, BR-5 | FR-31, FR-35 | FR-25 |
| FR-37 | FR-4 (P-2) | FR-32, FR-33 | FR-26 |
| FR-42, FR-43 | deferred (P-1) | FR-34 | deferred (D-7) |
| FR-8 | FR-9 | FR-38, FR-39 | FR-21 |
| FR-9, FR-10 | FR-10 | FR-40 | FR-22 |
| FR-11 | FR-11 | FR-41 | FR-9, BR-9 |
| FR-12, FR-13 | FR-12 | FR-44 | FR-27 |
| FR-14, FR-20 | FR-14 | FR-46 | FR-8 |
| FR-15 to FR-19 | FR-15 to FR-19 | FR-47 | FR-7 |
| FR-22 | FR-21 | FR-48 | FR-9, FR-13 |
| FR-23 | FR-23 | FR-49 | FR-13 |
| FR-24 | FR-22 | FR-50, FR-51, FR-52 | deferred (P-3, D-8) |

### 15.2 Business rules

| v1.4 | v1.5 | v1.4 | v1.5 |
| ---- | ---- | ---- | ---- |
| BR-1 | BR-1 | BR-15 | BR-7 |
| BR-2, BR-3 | BR-2 | BR-16 | BR-8 (P-4) |
| BR-4 | BR-3 | BR-17 | deferred (P-1) |
| BR-5, BR-7, BR-25 (e-mail) | BR-4 | BR-18, BR-19 | BR-12 |
| BR-6 | BR-5 | BR-20, BR-27 | BR-9 |
| BR-8 | BR-5, BR-6 | BR-21 | BR-11 |
| BR-9, BR-10, BR-11, BR-12, BR-25 (phone) | BR-11 | BR-22 | BR-14 |
| BR-13 | BR-9 | BR-23 | BR-4, BR-5, BR-9 (edges inline) |
| BR-14 | FR-25, FR-26 | BR-24 | BR-10 |
| BR-26 | BR-13 | BR-28 | deferred (P-3) |

### 15.3 Acceptance criteria

| v1.4 | v1.5 | v1.4 | v1.5 |
| ---- | ---- | ---- | ---- |
| AC-1, AC-2 | AC-1 | AC-39, AC-40 | AC-38 |
| AC-3, AC-4, AC-5, AC-79 | AC-2 | AC-41, AC-87 | AC-39 |
| AC-6, AC-7 | AC-3 | AC-45 | AC-40 |
| AC-8, AC-9, AC-77 | AC-4 | AC-46 | AC-41 |
| AC-10, AC-53, AC-80 | AC-5 | AC-47 | AC-47 |
| AC-11 | AC-6 | AC-48, AC-51 | AC-42 |
| AC-55 | AC-7 (P-2) | AC-49, AC-50 | AC-43 |
| AC-12, AC-13, AC-32, AC-93 | AC-8 | AC-52 | AC-44 |
| AC-42, AC-43, AC-86 | AC-9 | AC-89 | AC-45 |
| AC-14, AC-44, AC-84 | AC-10 | AC-70, AC-71, AC-72 | AC-46 |
| AC-54, AC-76 | AC-11 | AC-31 | AC-24, AC-47 |
| AC-94, AC-95 | AC-12 | AC-56, AC-57, AC-58, AC-59, AC-78 | deferred (P-1, P-2) |
| AC-90, AC-91, AC-92, AC-103 | AC-13 | AC-100, AC-101, AC-102 | deferred (P-3, D-8) |
| AC-15 | AC-14 | AC-21 | deferred (D-5) |
| AC-16, AC-97 | AC-15 | AC-22 (empty, offline, error) | AC-20 |
| AC-96 | AC-16 | AC-23 | AC-23 |
| AC-99 | AC-17 | AC-24 | AC-24 |
| AC-17, AC-18 | AC-18 | AC-25 | AC-25 |
| AC-19, AC-88 | AC-19 | AC-26 | AC-26 |
| AC-20, AC-22 | AC-20 | AC-27 | AC-27 |
| AC-67, AC-68, AC-81 | AC-21 | AC-28, AC-29, AC-69 | AC-28 |
| AC-83, AC-98 | AC-22 | AC-30, AC-75 | AC-29 |
| AC-33, AC-34 | AC-32 | AC-74 | AC-30 |
| AC-60, AC-61, AC-82 | AC-33 | AC-73 | AC-31 |
| AC-62, AC-63 | AC-34 | AC-35, AC-36 | AC-37 |
| AC-37, AC-38 | AC-35 | AC-64, AC-65, AC-66, AC-85 | AC-36 |
