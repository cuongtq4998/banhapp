# Admin Orders UI, part 11: Traceability, assets, open questions, change log (sections 10 to 12)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31]

## 10. Traceability (FR to screens)

| FR | Screens | Note |
| -- | ------- | ---- |
| FR-1, FR-2, FR-3 | S-A1, S-A2 | |
| FR-4 | S-A8, S-A19 (sign out); S-A1 (session ended) | The 7-day session itself has no screen |
| FR-5 | All (role-based entries); S-A8, S-A19 | Server enforcement is not UI |
| FR-6 | S-A1, S-A2, S-A3 | |
| FR-7 | S-A1 (`A_SESSION_ENDED`), S-A16 (deactivate) | |
| FR-36 | None | Silent token renewal; a refused reuse shows S-A1 |
| FR-37 | S-A18, S-A19 | |
| FR-42 | S-A20, S-A8 (reminder) | |
| FR-43 | S-A3, S-A18 | |
| FR-8, FR-9, FR-10, FR-11, FR-12, FR-13 | S-A4, S-A5 | |
| FR-41 | S-A4, S-A6 (`A_ORDER_GONE`) | |
| FR-14, FR-15 | S-A6 | |
| FR-16, FR-17 | S-A6 | |
| FR-18 | S-A6, S-A7 | |
| FR-19 | S-A6 (conflict), S-A7 | |
| FR-20 | S-A6 (`HistoryTimeline`) | |
| FR-21 | S-A8 and tab bar (owner only) | |
| FR-22 | S-A13, S-A14 | |
| FR-23 | S-A12 | |
| FR-24 | S-A10 | |
| FR-25 | S-A11 | |
| FR-26 | S-A9 | |
| FR-27 | S-A16, S-A17 | |
| FR-28 | S-A9 to S-A12, S-A14, S-A15, S-A17, S-A20 | Form rules in part 4 |
| FR-29 | S-A8 to S-A12, S-A14 (`A_NEW_ORDERS_ONLY`, `A_FEE_EFFECT`) | |
| FR-30 | None | Record kept by the server; no screen in scope |
| FR-31, FR-32, FR-33 | Part 7 notification table; S-A4, S-A6 | |
| FR-34 | S-A4 | |
| FR-35 | S-A8, S-A19, S-A16, S-A18 (sign out, deactivate, revoke) | |
| FR-38 | S-A13, S-A15 | |
| FR-39 | S-A14 | |
| FR-40 | S-A10 | |
| FR-44 | S-A7 (reason list only) | Counting is server behaviour |

Every FR with UI impact has a screen. FR-30, FR-36 and FR-44 (counting) have no UI by design.

## 11. Assets

- Board screens (reference only, text authoritative): `docs/design/reference/screens/{ios,android}-a1-admin-login.html` (S-A1, S-A2 pattern: the board shows telephone sign-in, replaced by e-mail), `-a2-admin-orders.html` (S-A4), `-a3-admin-order-detail.html` (S-A6), `-a4-admin-settings.html` (S-A8). The board's tab note ("only for the owner") is a design note, not screen text.
- No board for S-A3, S-A5, S-A7, S-A9 to S-A20: designed in this document from the board's glass cards, chips and fields. No mockups exist; none are required by the text specification.
- Pictures in `docs/design/reference/renders/` cover customer slices 1 only.

## 12. Open questions

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-D1 | AC-59 says recovery sign-in is "not offered" without a backup e-mail, but FR-1 forbids revealing whether an address is registered. Proposal: the recovery link is always visible, the flow looks the same, and the intro text states the condition (S-A3); a failure never says why. Acceptable? | Security against clarity | No | business | Open | |
| Q-D2 | Proposal: completing an order asks one confirmation (G-2 allows one) because it is final and may be done before the delivery date. Confirm, or keep it a single tap? | Mistaken taps against speed on delivery day | No | business | Open | |
| Q-D3 | Native Vietnamese review of the copy in parts 8 and 9 (tone: "Chủ tiệm", "nhân viên", "bạn"). | Quality of wording | No | business | Open | |
| Q-D4 | Staff have no tab bar (FR-21); proposal: an account button on the order list opens own devices and sign out (S-A19). Acceptable? | Staff must reach BR-1 rights (own devices) | No | business | Open | |
| TQ-D1 | Photo picker may return HEIC or large photos. Convert to JPEG and compress on the device before upload to meet "JPEG or PNG up to 5 MB"? Single multipart request or two steps? (relates to TQ-6) | S-A15 flow and errors | No | technical | Open | |
| TQ-D2 | Android tab bar: stable `NavigationBar` chosen; is use of experimental Material 3 Expressive toolbars allowed later? | Visual fidelity on Android | No | technical | Open | |
| TQ-D3 | Notification channel importance, sound and iOS interruption level for new orders. | Waking staff against noise | No | technical | Open | |
| TQ-D4 | Hide customer data in the app switcher on both platforms (blur snapshot, secure flag). | BR-15 | No | technical | Open | |
| TQ-D5 | Daily-limit save needs the list of dates above the new limit before saving (BR-10, AC-38): preview endpoint or save response with confirmation token? | S-A10 flow | No | technical | Open | |
| TQ-D6 | Sign out while offline: how is the server session ended later (queue, or rely on revoke/expiry)? | AC-11 | No | technical | Open | |
| TQ-D7 | Search needs 3 characters or the search key: does the API support partial phone/name match at the expected volume? (TQ-5) | S-A4 | No | technical | Open | |

Assumptions: A-D1 search combines with the status and date filters. A-D2 settings screens have no stale-view conflict rule; a refusal shows a generic error and reloads. A-D3 the order list shows no cached data when offline. A-D4 deselecting the last status chip is ignored.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version, based on PRD v1.2 (Approved). 20 screens. Design system v1.5 part 7 added. |
