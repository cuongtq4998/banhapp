# Admin Orders Test Plan: Document review, contradictions and untestable items (part 08)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.1). Holds: section 9.1 review of PRD v1.5 against the UI spec and the system documents. Owner = who must fix or answer. `requirements` = scribe-requirements, `architect` = atlas-architect, `design` = canvas-ui. Findings of PRD v1.2 that the simplification removed (backup e-mail, recovery, device list, history, lock, FR-34 hint) are deleted. [v1.1 | 2026-10-31]

Reviewed: `docs/product/admin-orders.md` and parts 01 to 08 (v1.5); `docs/design/admin-orders-ui.md` and parts 01 to 11 (v1.0, based on PRD v1.2); `docs/system/api/05` to `08`, `architecture/07` to `09`, `data-model/04`, `05`, `auth.md` v2.2, `session-lifecycle.md`, `order-lifecycle.md`. [v1.1 | 2026-10-31]

## 9.1 Contradictions between PRD, UI spec and system documents

| ID | Finding | Documents | Owner | Cases |
| -- | ------- | --------- | ----- | ----- |
| R-1 | FR-19 says repeating a change is not an error (retry after a lost reply). api/06 answers 404 for a retry once the order left the window, and AC-22 makes every Completed/Cancelled order of an old open order leave the list at once. A lost reply on closing an old order shows an error although the change worked | FR-19, AC-22, api/06 10.x, ADR-0028 | architect (replay beyond the window), requirements (accept 404 or not) | TC-B68, C23, C38 |
| R-2 | Search for an old open order (placed over 90 days ago, New/Confirmed): PRD BR-9 lists it by default but BR-10 and AC-19 say nothing; architecture/09 TQ-12 says search keeps the strict 90 days, so the list finds it and search does not | BR-9, BR-10, architecture/09 25.1 | requirements | TC-B62, B68 |
| R-3 | Residual lock-out: with no address lock, an outsider can still use the 3 requests an hour for the owner address (and 5 wrong entries void a code) so the owner may be refused a code for the whole hour. Severity medium if confirmed | BR-4, AC-4 | requirements | TC-B09, B11 |
| R-4 | api/08 and architecture/09 are partly updated (no `CODE_LOCKED`) but api/05 still has recovery sign-in with `owner_code`/`backup_code`, challenge ids and device endpoints; data-model/04 still has backup columns | api/05 to 07, data-model/04, architecture/07, session-lifecycle | architect | all auth cases |
| R-5 | PRD BR-8 has four reasons; api/06 10.x, api/08 and data-model/03 list five (`customer_asked`, `day_full`, `cannot_deliver`, `cannot_reach_customer`, `fake_spam`). The UI spec also says "exactly five reasons" | BR-8, AC-28, api/06, data-model, design 03/08/10 | architect, design | TC-B78, B79, C22 |
| R-6 | No limit per client address in the PRD; api/05 and architecture/08 add 20 code requests an hour per client. Not a contradiction but an unrequested rule that tests must read as configuration | BR-4, architecture/08 | architect | TC-B19 |
| R-7 | PRD FR-9 and AC-22 put open orders of any age in the default list; api/06 returns only orders of the last 90 days without `view=unfinished`, and `view=unfinished` still exists although the Unfinished view is deferred (FR-13 keeps only the badge) | FR-9, FR-13, BR-9, api/05 and 06, architecture/09 | architect | TC-B57, B66, B72 |
| R-8 | api/06 names the count `unfinished_count` and architecture/09 sections 25.2 to 25.3 describe the banner and chip as live; PRD v1.5 makes the badge the only part kept (Q-22) | FR-13, api/06, architecture/09 | architect | TC-B54, C14 |
| R-9 | PRD FR-4 and AC-7 are still marked "PROPOSAL P-2", FR-13 mentions P-3 and BR-8 P-4, but the task states the PRD is approved. If the labels stay, the verdict cannot tell whether these Must ACs are in force | FR-4, FR-13, BR-8, AC-7 | requirements (remove the labels once approved) | TC-B23 to B25, B78 |
| R-10 | `auth.md` and place-order documents must say that cancelled orders do not count toward 5 orders per phone per 24 h except "fake or spam" (FR-27); `auth.md` v2.2 is based on PRD v1.4 | FR-27, auth.md, place-order | architect | TC-B104 |
| R-11 | Lowering the daily limit alone below the stored minimum: AC-36 gives the pair rule for saves but not the state "limit 3 saved while minimum 5 exists"; a stuck state is possible | BR-11, AC-36 | requirements | TC-B125, B129 |
| R-12 | BR-13 "phone the owner has not used before" vs architecture/09 TQ-13 "no live session with the same installation id": sign out then sign in on the same phone sends a notice under the second rule, not under the first | BR-13, AC-12, architecture/09 | requirements | TC-B44 |
| R-13 | No rule for NFC/NFD names and for case-insensitive duplicate cake or district names beyond "unique" | BR-12, BR-10 | requirements | TC-B61, B141 |
| R-14 | Paging consistency when orders change between pages is not specified; AC-23 only says no duplicate | AC-23 | architect | TC-B70 |
| R-15 | FR-9 does not say whether the red mark appears on Completed/Cancelled rows with an old date in the All view; AC-16 shows none. Same for "last changed by" of a customer-created order (name or "customer") | FR-9, AC-16, FR-14, AC-24 | requirements | TC-B52, B73 |
| R-16 | The 5 MB image is 5 242 880 bytes (BR-12, api/07) but api conventions cap every body at 8 KB; HEIC is converted on the phone, so the server must refuse HEIC bytes | BR-12, api conventions | architect | TC-B115, B116 |
| R-17 | AC-22 says a final old order is "gone for everyone" yet Q-8 allows Complete at any time; an old Confirmed order can be completed once, not corrected after (no undo, no history). Business impact only if the owner expected a correction path | AC-22, BR-2 | requirements | TC-B66 |

## 9.2 UI spec still on PRD v1.2 (all owned by design)

| ID | Finding | Documents | Owner | Cases |
| -- | ------- | --------- | ----- | ----- |
| R-30 | The UI spec index says "Based on product/admin-orders.md v1.2"; it must be reissued for v1.5 | design/admin-orders-ui.md | design | all TC-C |
| R-31 | Removed features are still specified: devices screen, backup e-mail and recovery screens, history panel, multi-select status chips with "Tất cả", Unfinished view/chip/banner, push hint and reminder, lock message with minutes | design 02, 03, 04, 06, 08, 09, 10 | design | TC-C03, C14, C20, C48 |
| R-32 | Missing screens and strings: "Sign out all other phones" control and its texts, a single "To do" list, red "due today"/"overdue N days" marks, four reasons, void-code message without a wait, new-device notice is mail only (no screen) | design 02, 03, 06, 08 | design | TC-C03, C06, C12, C22 |
| R-33 | Settings: the UI spec has more than five entries (devices, backup e-mail, security); AC-48 allows exactly five | design 04, 06 | design | TC-C30 |
| R-34 | Reference screens A1 to A4 still show phone sign-in and "remembered N days" | design/reference | design | TC-C01 |

## 9.3 Untestable or only partly testable items

| ID | Item | Why | Owner |
| -- | ---- | --- | ----- |
| R-40 | AC-42 "within 60 seconds", AC-7/AC-10 "within 5 minutes": measured on the server and the fake provider only | Needs real services; "normal conditions" is not measurable | requirements (define), architect |
| R-41 | AC-30 and AC-31 are goal checks (tap counts) with no timing; counted by hand in TC-C24, C25 | Manual step counting | requirements |
| R-42 | Performance figures in the NFR are indicative on the test host | Single host | requirements |
