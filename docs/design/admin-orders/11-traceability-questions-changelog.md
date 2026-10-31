# Admin Orders UI, part 11: Traceability, assets, open questions, change log (sections 10 to 12)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.1 | 2026-10-31]

## 10. Traceability (PRD v1.6 FR and AC to screens) [v1.1 | 2026-10-31]

| FR | AC | Screens | Note |
| -- | -- | ------- | ---- |
| FR-1 | AC-1 to AC-4 | S-A1, S-A2 | One code for all accounts; void code shows `A_CODE_EXPIRED` |
| FR-2 | AC-5, AC-6 | S-A1 (`A_SESSION_ENDED`), S-A6, S-A13 (sign out) | The 7-day renewal has no screen |
| FR-3 | AC-8 | All (role-based entries); S-A6 absent for staff | Server enforcement is not UI |
| FR-4 | AC-7 | S-A6, S-A13 (`A_SIGNOUT_OTHERS`) | One button, one dialog |
| FR-5 | AC-9, AC-10 | S-A12 | |
| FR-6, FR-7 | AC-11, AC-12 | None (invisible) | Refused reuse shows S-A1 |
| FR-8 | AC-13 | None (invisible); same screens with demo data | |
| FR-9 | AC-14 to AC-16, AC-21 to AC-23 | S-A3 | Order, row fields, red marks, 90 days, paging |
| FR-10 | AC-18 | S-A3 (status chips, date menu) | One status, one date |
| FR-11 | AC-19 | S-A3 (search) | |
| FR-12 | AC-20 | S-A3 (states, pull-down) | |
| FR-13 | AC-17 | S-A3 (`TabBadge`, staff header number) | Count from the server answer |
| FR-14, FR-15 | AC-24, AC-25 | S-A4 | "Last changed by" line, no history |
| FR-16 | AC-26 | S-A4 | One tap |
| FR-17 | AC-27 | S-A4 (`ConfirmDialog`) | |
| FR-18 | AC-28 | S-A4, S-A5 | Four reasons |
| FR-19 | AC-29 | S-A4 (conflict, repeat) | |
| G-1, G-2 | AC-30, AC-31 | S-A4, S-A5, notification table | Tap counts |
| FR-20 | AC-48 | S-A6 | Exactly five entries |
| FR-21 | AC-32 to AC-34 | S-A7, S-A8 | |
| FR-22 | AC-35, AC-36 | S-A9 | |
| FR-23 | AC-37, AC-38 | S-A10 | |
| FR-24 | AC-39 | S-A11 | |
| BR-11 | AC-40, AC-41 | S-A8 to S-A12 | Form rules in part 4 |
| FR-25, FR-26 | AC-42, AC-43 | Notification table; S-A3, S-A4 | |
| BR-7 | AC-44, AC-45 | S-A1 (after sign out), task switcher rule | |
| FR-27, BR-8 | AC-46 | S-A5 (reason list only) | Counting is server behaviour |
| BR-3 | AC-47 | None (record only; `A_LAST_CHANGED` shows the last change) | |

Every FR with UI impact has a screen; AC-11, AC-12, AC-13, AC-47 and FR-6, FR-7, FR-8 have no UI by design. Check done on 2026-10-31 against all 27 FR and 48 AC of the v1.5 text.

## 11. Assets

- Board screens (reference only, text authoritative): `docs/design/reference/screens/{ios,android}-a1-admin-login.html` (S-A1, S-A2 pattern: the board shows telephone sign-in, replaced by e-mail), `-a2-admin-orders.html` (S-A3), `-a3-admin-order-detail.html` (S-A4), `-a4-admin-settings.html` (S-A6). The board's tab note is a design note, not screen text.
- No board for S-A5 and S-A7 to S-A13: designed from the board's glass cards, chips and fields. No mockups exist.

## 12. Open questions

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-D1 | Recovery link visibility | Removed with PRD P-1 | No | business | Closed (removed) | [v1.1 | 2026-10-31] |
| Q-D2 | Complete asks one confirmation | PRD FR-17 and AC-27 now require it | No | business | Closed | [v1.1 | 2026-10-31] |
| Q-D3 | Native Vietnamese review of the copy in parts 8 and 9 (tone: "Chủ tiệm", "nhân viên", "bạn"). | Wording | No | business | Open | |
| Q-D4 | Staff have no tab bar; proposal: an account button in the list header opens the sheet S-A13 (sign out buttons), and the red unfinished number sits beside the title. Acceptable? | Staff reach "sign out all other phones" (FR-4) and see FR-13's number | No | business | Open | |
| Q-D5 | "Sign out all other phones" asks one confirmation (the action affects other staff phones at once). Keep, or make it one tap? | Mistaken tap against speed (rare action) | No | business | Open | |
| TQ-D1 | Photo picker may return HEIC or large photos: convert and compress on the device; single multipart request or two steps? | S-A8 | No | technical | Open | |
| TQ-D2 | Android tab bar: stable `NavigationBar`; experimental Expressive toolbars later? | Fidelity | No | technical | Open | |
| TQ-D3 | Notification channel importance, sound and iOS interruption level. | Waking staff against noise | No | technical | Open | |
| TQ-D4 | Hide customer data in the app switcher on both platforms. | BR-7 | No | technical | Open | |
| TQ-D5 | Daily-limit save needs the dates above the new limit first: preview endpoint or confirmation token? | S-A9 | No | technical | Open | |
| TQ-D6 | Sign out while offline: how is the server session ended later? | AC-6 | No | technical | Open | |
| TQ-D7 | Search needs 3 characters: does the API support partial phone and name match at volume? | S-A3 | No | technical | Open | |
| TQ-D8 | The list response should carry the server date (Vietnam) and the unfinished count, so the app computes "due today / overdue N days" and the tab number without the device clock or loaded rows (FR-9, FR-13). Confirm for the API. | S-A3 correctness | No | technical | Open | [v1.1 | 2026-10-31] |

Assumptions: A-D1 search combines with the status and date filters. A-D2 settings screens have no stale-view conflict rule. A-D3 the list shows no cached data when offline. A-D4 the notification permission request shows directly after the first sign-in with no explanation card, and an iOS denial cannot be asked again (acceptable under D-7). A-D5 the date chip is a native menu with a native date picker, not a custom sheet. [v1.1 | 2026-10-31]

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.1 | 2026-10-31 | Simplified to match PRD v1.6 (27 FR, 14 BR, 48 AC): 20 screens to 13. Removed recovery, devices, backup e-mail, date sheet, history, Unfinished view and chip, banner, notification hint and priming card. Added "Sign out all other phones", one "To do" list with tab badge and red due marks, single status and date filter, four cancel reasons, Settings of five entries, "how a day works" flows. Voided code shares the expired-code text. Design system part 7 v1.6. |
| 1.0 | 2026-10-31 | First version, based on PRD v1.2 (Approved). 20 screens. |
