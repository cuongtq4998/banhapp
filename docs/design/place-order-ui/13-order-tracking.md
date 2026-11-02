# Place Order UI, part 13: Order tracking by phone (screens S-10, S-11) - DRAFT

Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Version 0.1 [v0.1 | 2026-11-02]. Status: **Draft** until the owner approves place-order part 08 (`product/place-order/08-order-tracking.md`, Draft). Traces: FR-22 to FR-27, BR-16 to BR-18, AC-38 to AC-47 (draft numbering), FR-28 to FR-30. API: `api/10-customer-order-lookup.md` (`POST /v1/orders/lookup`), ADR-0034. Copy and accessibility: [part 14](14-order-tracking-copy-a11y.md). Fake data only.

## S-10 Track orders (entry and phone entry)

- Purpose: the customer sees where their orders are, with no sign-in and no push. Entry: a "Theo dõi đơn" row on the shop home or menu (`T_TRACK_ENTRY`) and the "Follow this order" button on the confirmation screen S-9 (below). Exit: back.
- Layout: `TopBar` `T_TRACK_TITLE`; short line `T_TRACK_HELP` (enter the phone number used to order); `TextField` `T_F_PHONE` (phone keyboard, label above, autofill off, the field keeps the last phone typed during the session only; nothing is stored on the device by the app); `PrimaryButton` `T_TRACK_SUBMIT`. The phone is normalised by the server (spaces, dots, leading 0); the client only checks that it has 9 to 11 digits after cleaning, else `T_ERR_PHONE` (the 422 `VALIDATION_FAILED` for the phone field shows the same text). Nothing is searched while typing.
- Privacy line `T_TRACK_PRIVACY` under the field: only the masked phone and district are shown. The screen never shows name, street or note.
- From the confirmation: S-9 gets a secondary button `T_FOLLOW_ORDER`; it opens S-10 with the order's phone already filled and runs the lookup at once (the phone is in memory from the order just sent, not stored).
- States: Default (field, button); Loading (button spinner, field disabled); Error (field error `T_ERR_PHONE`); Offline (`T_OFFLINE`, button stays, no request); Rate limited, see S-11.

## S-11 Track orders, result list

- Layout: below a sticky summary line `T_RESULT_FOR` with the masked phone (`+84 900 000 ***` as sent by the server); list of order cards, newest first (`placed_at` descending); pull to refresh (native `refreshable` / Material pull-to-refresh) reruns page 1; the list shows `T_AS_OF` (updated time) at the bottom of the page.
- Paging: 10 per page, at most 5 pages. The next page loads when the person reaches the end (a `T_LOAD_MORE` row with spinner; on failure the row becomes the retry button `T_RETRY`). After the last page (no cursor), if 5 pages were loaded the line `T_LIST_END_LIMIT` says that the newest 50 are shown and the shop can help with older ones (with shop contact); otherwise nothing.
- Order card: `T_ORDER_CODE` (selectable, monospace digits), placed date; `District` name only (never the street); the five-step stepper (reuse of `OrderStepper`, customer variant, design-system part 8: steps `T_STEP_RECEIVED`, `T_STEP_PROCESSING`, `T_STEP_SCHEDULED`, `T_STEP_DELIVERING`, `T_STEP_FINISHED`); date block: the requested date and slot as `T_REQUESTED`; from step 3 the expected date `T_EXPECTED` with the fixed note `T_EXPECTED_MAY_MOVE` (it may move); cakes lines (name, quantity) and `T_CAKES_TOTAL`; fee block: until the real fee is known `T_FEE_ESTIMATE_LINE` ("Phí giao dự kiến: {amount}", labelled as estimate, no total); once known `T_FEE_FINAL` and `T_TOTAL_COLLECT`; real fee 0 shows `T_FEE_FREE`. After a correction only the latest fee is shown, with no history.
- Cancelled card: badge `T_STATUS_CANCELLED`, no stepper, no reason, no fee block; the shop contact `T_CANCELLED_CONTACT` with two actions `T_CALL_SHOP` and `T_ZALO_SHOP` (numbers from the catalog contact, native phone and Zalo link).
- Finished card: all five steps done, the real fee and amount to collect remain visible; shown for 30 days then no longer returned (`T_FINISHED_NOTE_30`).
- Empty (no orders, or a number that never ordered): the same screen and the same text for both, `T_EMPTY_TITLE` and `T_EMPTY_BODY` ("Không tìm thấy đơn nào cho số này gần đây"), with the shop contact and a `PrimaryButton` `T_ORDER_NOW`. The text never says the number is or is not a customer, never suggests a typo of a known number, and the layout, animation and timing do not differ from a result (loading spinner is shown for at least the same short time).
- Rate limit (429 `RATE_LIMITED`): `InlineMessage` Warning `T_ERR_RATE` with the wait from `Retry-After` shown as minutes and seconds (`{wait}`), the submit and pull-to-refresh are disabled with a live countdown, no mention of which limit applied; the same text appears whether the phone has orders or not.
- Loading: card skeletons (3), stepper skeleton inside. Error (network or 5xx): `T_ERR_GENERIC` and `T_RETRY`; page 2+ errors keep the loaded pages. Offline: `T_OFFLINE` banner; earlier loaded results stay on screen as read-only with `T_STALE_AS_OF`; refresh disabled. Invalid cursor (422): reload page 1 silently once, then `T_ERR_GENERIC`.
- Disabled: submit during a request. Success: the list.
- Motion: step change after refresh animates the stepper marker with the standard spring, fade only under reduced motion. Haptics: none on lookup, light impact on the pull-to-refresh release (native).
- Portrait and landscape: honestly no structural difference; in landscape the cards are limited to the readable width (about 600 dp, centred) and the list scrolls; the phone field and button stay above the keyboard.
- Native base: iOS `List` with `refreshable`, `ContentUnavailableView` for empty and error (iOS 17, no `#available`); Android `LazyColumn` with `PullToRefreshBox` and Material 3 cards. Liquid Glass applies only to the system bar and sheets, not to the cards (content layer stays opaque for reading).

## Security notes for the design (to scribe and atlas)

- The phone is submitted in the request body, never kept in navigation state, logs or deep links. No deep link opens S-11 with a phone.
- Because anyone knowing a phone can see its orders (accepted in ADR-0034), the card shows district only and masked phone; confirm with scribe whether the order codes and cake names are acceptable for strangers (BUSINESS question below).
