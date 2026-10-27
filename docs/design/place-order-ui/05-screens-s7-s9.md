# Place Order UI, part 5: Screen specs S-7 Recipient, S-8 Review, S-9 Confirmation (sections 5.7 to 5.9)

[v1.4 | 2026-10-27] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Content unchanged from v1.3; section numbers are the original ones.

### 5.7 S-7 Order step 3: Recipient and address

- Purpose: collect name, phone, delivery address, district, optional note (FR-8, FR-18).
- Entry/Exit: from S-6, or from S-8 via back or Edit. Exit to S-8, or back to S-6.
- Layout: `TopBar`, `StepIndicator` (`STEP3`); `GlassCard` with `TextField` Text `FIELD_NAME`, `TextField` Phone `FIELD_PHONE`, `TextField` Text (multiline, two lines) `FIELD_ADDRESS`, `PickerField` `FIELD_DISTRICT`; a fee line `DISTRICT_FEE` appears under the picker once a district is chosen; `GlassCard` with `TextField` Multiline `FIELD_NOTE` and counter `NOTE_COUNTER`; `BottomActionBar` with `PrimaryButton` `COMMON_NEXT`.
- Data shown: the entered values; the flat fee of the chosen district (AC-11, no free-delivery wording exists); the list of served districts only, so an unserved district cannot be chosen (AC-11).
- Actions:

| Action | Result | FR |
| ------ | ------ | -- |
| Type in a field | Value kept in flow data. Error under the field clears when the field becomes valid. | FR-8, FR-13 |
| Open district picker | A sheet lists served districts, each row shows name and fee (`DISTRICT_FEE` format); tapping a row selects it and closes the sheet. | FR-8 |
| Type in note | Up to 200 characters. A 201st typed or pasted character is not inserted; `ERR_NOTE_MAX` appears next to the field; pasted text is cut at 200 (AC-26). | FR-18 |
| Tap `COMMON_NEXT` | Validates all required fields at once. If any fails, an error appears next to each failing field, focus moves to the first failing field, and the flow does not advance (AC-12). If all pass, go to S-8. | FR-13 |
| Back | Return to S-6, nothing lost. | FR-15 |

- States:

| State | Behaviour |
| ----- | --------- |
| Default | Empty fields on first visit, filled when revisiting. Next is enabled (errors are shown on tap, so the customer sees what to fix). |
| Loading | District list loading: the picker shows a spinner state and is disabled; other fields are usable. Next is enabled but treats district as missing. |
| Empty | District list is empty: picker shows `DISTRICT_EMPTY`, Next stays disabled. |
| Error | District list failed to load: `InlineMessage` `DISTRICT_ERR` with `COMMON_RETRY` next to the picker. Field errors follow the Validation table. |
| Disabled | Next disabled only when the district list is Empty. |
| Success | N/A: no submit; valid input moves on to S-8. |

- Validation:

| Field | Rule | Message key |
| ----- | ---- | ----------- |
| Name | Required | `ERR_NAME_REQUIRED` |
| Phone | Required | `ERR_PHONE_REQUIRED` |
| Phone | [v1.1 | 2026-10-25] Must be a Vietnamese mobile number (ADR-0009): spaces, dots, hyphens and parentheses are ignored; a leading `+84` or `84` is read as `0`; valid when 10 digits, `0` then `3`, `5`, `7`, `8` or `9`. Landlines and foreign numbers are invalid. | `ERR_PHONE_INVALID` |
| Name | [v1.1 | 2026-10-25] At most 100 characters (input limit, no message) | none |
| Address | [v1.1 | 2026-10-25] At most 250 characters (input limit, no message) | none |
| Address | Required | `ERR_ADDRESS_REQUIRED` |
| District | Required, from the served list | `ERR_DISTRICT_REQUIRED` |
| Note | Optional, at most 200 characters | `ERR_NOTE_MAX` |

Keyboards and input hints: name uses the name keyboard with sentence capitalisation of words; phone uses the numeric phone pad; address uses the default keyboard; autofill hints for name, phone and address are enabled (native). Return key moves to the next field; the note field's return key inserts a new line.

### 5.8 S-8 Order step 4: Review

- Purpose: show the full order before confirmation, state which data is collected and why, and confirm (FR-9, FR-10, FR-11 trigger, FR-16, FR-17).
- Entry/Exit: from S-7. Exit to S-9 on success; Edit controls go to S-5, S-6 or S-7; back goes to S-7.
- Layout: `TopBar`, `StepIndicator` (`STEP4`); `InlineMessage` area at the top for rule and send errors (hidden in Default); `GlassCard` "cakes": section title `REVIEW_SEC_CAKES`, one `SummaryRow` per cake with quantity above 0 (`REVIEW_ITEM` and line price), `COMMON_EDIT` control to S-5; `GlassCard` totals: `SummaryRow` Money `REVIEW_FEE`, `SummaryRow` Total `REVIEW_TOTAL`; `GlassCard` delivery: `REVIEW_DATE`, `REVIEW_TIME` (edit to S-6), `REVIEW_NAME`, `REVIEW_PHONE`, `REVIEW_ADDRESS` (address and district), `REVIEW_NOTE` only when a note was entered (edit to S-7); `NoticeText` `REVIEW_PRIVACY`; `BottomActionBar` with `PrimaryButton` `BTN_CONFIRM`.
- Data shown: only cakes with quantity above 0 (AC-6); line price = price x quantity; delivery fee of the chosen district; total = sum of line prices + fee (BR-5, AC-14); date, time, name, phone, address, note if any. No payment line, method or instruction (AC-27).
- Actions:

| Action | Result | FR |
| ------ | ------ | -- |
| Tap an Edit control | Go to the matching step; data kept (AC-18). | FR-15 |
| Tap `BTN_CONFIRM` | Sends the order. Immediately: button shows loading with `BTN_SENDING`, is disabled, and the whole review is inert, so repeated taps cannot send twice (AC-19). Result in under 10 s (PRD performance target), otherwise treated as a timeout. | FR-11, FR-16 |
| Tap `COMMON_RETRY` in a send-error banner | Sends again as the same attempt; at most one order results (FR-16; mechanism is architect's, Q-T1). | FR-16, FR-17 |

- States:

| State | Behaviour |
| ----- | --------- |
| Default | Review shown, confirm enabled. |
| Loading | Sending: confirm shows a spinner and `BTN_SENDING`, disabled; Edit controls and back are disabled until the result. |
| Empty | N/A: S-5 prevents reaching review with fewer than MIN_QTY cakes; a cleared date leads back to S-6 before review. |
| Error | Two kinds, shown in the top `InlineMessage` (Error), flow data kept in both: (a) Rule not met, confirm blocked until fixed (FR-10): `ERR_MIN_QTY`, `ERR_DATE_CAPACITY` (also the message when another customer took the capacity, AC-9, AC-22), `ERR_DATE_LEAD`, `ERR_DATE_HORIZON`, `ERR_DISTRICT_UNSERVED`, and [v1.1 | 2026-10-25] `ERR_PRODUCT_UNAVAILABLE` ([v1.2 | 2026-10-26] a cake in the order was hidden by the shop, BR-13, AC-34: the order is not sent or stored, all entered data is kept, confirm is blocked; the action `DATE_EMPTY_ACTION` opens S-5, which shows the Cake removed state with the cake name; the customer continues with the remaining cakes or, if the total is below MIN_QTY, adds cakes) and `ERR_SLOT_UNAVAILABLE` (action opens S-6 with `ACTION_CHOOSE_SLOT`); each has an action button that opens the step to fix (S-5, S-6 or S-7, using `DATE_EMPTY_ACTION` for quantity and `ACTION_CHOOSE_DATE`, `ACTION_CHOOSE_DISTRICT`). (b) Not sent: `ERR_OFFLINE`, `ERR_SERVER`, `ERR_TIMEOUT` or [v1.1 | 2026-10-25] `ERR_RATE_LIMITED` with `COMMON_RETRY`; no confirmation screen appears (AC-20). (c) [v1.1 | 2026-10-25] Price changed (server answers 409 `PRICE_CHANGED` with the new prices; ADR-0010, owner decision: the order is rejected and the customer re-reviews): nothing was sent; the cake rows, line prices, fee and total are replaced with the new values at once (changed amounts are highlighted for the session of this screen with `color.warningContainer` behind the value, and spoken in the alert), `InlineMessage` (Info, announced as an alert) shows `MSG_PRICE_CHANGED`, and `BTN_CONFIRM` stays enabled so the customer confirms again at the new total. The message clears when the customer taps Edit or confirms. |
| Disabled | Confirm is disabled while Loading and while a rule error is shown (kind a). After the customer fixes it and returns, confirm is enabled again. Confirm stays enabled after a kind b or kind c message so retry or re-confirm is possible. For `ERR_RATE_LIMITED` the retry button stays enabled (the server may answer again; the customer decides). |
| Success | On received: transition to S-9 (see 5.9). No intermediate success state is shown on S-8. |

- Validation: all ordering rules BR-1 to BR-4 and BR-8 are checked at confirmation time (FR-10); the messages are the keys above. Field validation was done on S-7.

### 5.9 S-9 Confirmation

- Purpose: tell the customer the order is received and give the order code (FR-11, FR-12).
- Entry/Exit: from S-8 only. Exit to S-2. Back gesture and the Android back button also go to S-2; they never return to S-8 (prevents a second send). No other exit.
- Layout: no `TopBar`; `StatusMark`; title `CONF_TITLE` (`type.title.large`); `GlassCard` with label `CONF_CODE_LABEL` and `OrderCodeDisplay`; message `CONF_MESSAGE`; row of two `ContactButton` (Zalo, Phone); `BottomActionBar` with `SecondaryButton` `CONF_BTN_HOME`.
- Data shown: order code (unique per order, AC-16); the received-and-contact message. No tracking, no status, no cancel, no payment information, no order recap (AC-15, AC-25, AC-27).
- Actions:

| Action | Result | FR |
| ------ | ------ | -- |
| Tap Zalo / Phone | Same behaviour as S-2 (AC-17). | FR-12 |
| Tap `CONF_BTN_HOME` | Clears flow data and goes to S-2. | FR-11 |
| Press and hold the code | Native text selection and copy (no extra copy button). | FR-11 |

- States:

| State | Behaviour |
| ----- | --------- |
| Default | As above, `StatusMark` animation played once. |
| Loading | N/A: shown only after the order is received. |
| Empty | N/A: a code always exists on this screen. |
| Error | Only for the contact buttons: `Toast` with `ERR_OPEN_ZALO` or `ERR_OPEN_PHONE`. |
| Disabled | N/A: all controls are always available. |
| Success | This screen is the success state (the animation and success haptic play on entry). |

- Validation: none. Copy shall say "received" and "the shop will contact you", never "accepted" or "guaranteed" (AC-25).
