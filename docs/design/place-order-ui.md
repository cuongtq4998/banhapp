# Place Order: UI Specification

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.0                                                                   |
| Last updated | 2026-10-25                                                            |
| Status       | Draft                                                                 |
| Owner        | canvas-ui                                                             |
| Based on     | product/place-order.md v1.2 (Approved)                                |
| Related      | design/design-system.md; pipeline/place-order/00-request.md; mockups (reference only, private link in the PRD) |

## 1. Overview

Scope: the Customer app on iOS and Android, from launch to the confirmation screen. The Admin app (staff and owner) is out of scope (PRD non-goals). One specification covers both platforms; differences are in section 6. Visual direction: iOS uses Liquid Glass, Android uses Material 3 Expressive. Component and token names come from `design-system.md`.

Global rules that apply to every screen:

- All text is Vietnamese and referenced by key (FR-14). Text lives in section 8.
- Money is shown as whole dong (BR-5). Format and rules are in the design system (principle 4).
- No payment information, payment method, payment hint or payment word appears anywhere (FR-19, AC-27). Reviewers shall check every key in section 8.
- Launch data (shop name, greeting, contacts, prices, districts, slots) is shown exactly as received. No "sample", "demo" or "test" marker is shown (AC-29).
- Dates and times are shown in Vietnam time (UTC+7), whatever the device time zone (A-1).
- No screen offers tracking, status or cancellation (non-goals).

Placeholders in text: `{n}`, `{min}`, `{max}`, `{days}`, `{amount}`, `{date}`, `{name}`, `{code}`, `{start}`, `{end}`. Values for `{min}` (MIN_QTY), `{days}` (LEAD_DAYS) and `{max}` (MAX_DAYS_AHEAD) come from configuration, never typed into copy.

## 2. Research summary

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| iOS 26 Liquid Glass in SwiftUI: `glassEffect(_:in:)` with `GlassEffectContainer` for grouped glass shapes; iOS 26 and later | https://developer.apple.com/documentation/swiftui/glasseffectcontainer.md | 2026-10-25 | High |
| Glass button styles (`.glass`, `.glassProminent`), `.interactive()`, `glassEffectID` morphing; glass belongs on the navigation and action layer, not on content | https://levelup.gitconnected.com/swiftui-liquid-glass-from-basic-to-a-little-advance-cdef4e4c5b90 ; https://medium.com/@veersr9/ios-26-liquid-glass-in-swiftui-a-practical-reference-demo-app-liquidglassreference-69b8d46dc055 | 2026-10-25 | Medium (secondary) |
| Fallback before Liquid Glass: SwiftUI `Material` backgrounds | Apple SwiftUI `Material` documentation | 2026-10-25 | Unverified (not read) |
| Material 3 Expressive in Compose: `ButtonGroup`, `FloatingToolbar`, `FlexibleBottomAppBar`, `LoadingIndicator`, `MaterialExpressiveTheme`, large flexible top app bar; some APIs experimental in 1.4.0 alpha builds | https://proandroiddev.com/material-3-expressive-design-a-new-era-9ea77959a262 ; https://proandroiddev.com/material-3-expressive-design-a-new-era-part-2-6a93483c98b0 | 2026-10-25 | Medium (third-party) |
| Official Material 3 Expressive guidance (stable status, motion scheme) | https://m3.material.io/blog/building-with-m3-expressive | 2026-10-25 | Unverified (page unreadable) |

Decisions that follow: glass is used for cards and the floating bar only; all long text sits on cards with contrast kept at 4.5:1; every glass surface has the `material.fallback` rendering. The system date pickers are not used for the date step because capacity-based unavailability must be shown per date (unverified that native pickers cannot do this; the custom `DateGrid` is the specified behaviour either way).

## 3. User Flow

```mermaid
flowchart TD
    A[App start] --> S1[S-1 Launch]
    S1 --> S2[S-2 Home]
    S2 -->|View products| S3[S-3 Product list]
    S2 -->|Place order| S5[S-5 Choose cakes]
    S2 -->|Zalo / Phone| EXT[Zalo app / phone dialer]
    S3 --> S4[S-4 Cake detail]
    S4 -->|Order this cake, qty 1| S5
    S5 -->|total >= MIN_QTY| S6[S-6 Date and time]
    S6 -->|date and slot chosen| S7[S-7 Recipient and address]
    S6 -->|no selectable date| S5
    S7 -->|valid fields| S8[S-8 Review]
    S8 -->|Edit| S5
    S8 -->|Edit| S6
    S8 -->|Edit| S7
    S8 -->|Confirm| SEND{Send order}
    SEND -->|received| S9[S-9 Confirmation]
    SEND -->|rule not met: capacity, date, district, quantity| S8E[S-8 rule message, confirm blocked]
    S8E -->|change choice| S5
    S8E -->|change choice| S6
    S8E -->|change choice| S7
    SEND -->|offline / server error / timeout| S8N[S-8 not-sent message, data kept]
    S8N -->|Retry| SEND
    S9 -->|Home| S2
    S9 -->|Zalo / Phone| EXT
```

Entry points: app start (S-1); S-4 starts the flow with that cake at quantity 1 (FR-4); S-2 starts the flow with no cake chosen. Exit points: S-9 to S-2; leaving the flow from step 1 with the back control returns to the previous screen and discards flow data. Flow data is kept for the whole time the customer moves between steps (FR-15).

Step count after "Place order": 4 steps (cakes, date and time, recipient, review) plus the confirmation, within G-1 (at most 6).

## 4. Screen Inventory

| ID | Name | App | Purpose | FRs covered |
| -- | ---- | --- | ------- | ----------- |
| S-1 | Launch | Customer | Logo-only screen on start | FR-1, FR-14 |
| S-2 | Home | Customer | Shop name, greeting, contact, entry to products and order | FR-2, FR-14, FR-19 |
| S-3 | Product list | Customer | Four cakes with picture, name, description, price | FR-3, FR-14 |
| S-4 | Cake detail | Customer | One cake and the button that starts an order | FR-3, FR-4, FR-14 |
| S-5 | Order step 1: Choose cakes | Customer | Quantity per cake | FR-5, FR-4, FR-10, FR-14, FR-15 |
| S-6 | Order step 2: Date and time | Customer | Receiving date and time slot | FR-6, FR-7, FR-10, FR-14, FR-15 |
| S-7 | Order step 3: Recipient and address | Customer | Name, phone, address, district, note | FR-8, FR-13, FR-18, FR-14, FR-15 |
| S-8 | Order step 4: Review | Customer | Full order review, privacy sentence, confirm, rule and send errors | FR-9, FR-10, FR-16, FR-17, FR-18, FR-15, FR-14 |
| S-9 | Confirmation | Customer | Order code, received message, contact buttons | FR-11, FR-12, FR-14, FR-19 |

Error and offline states have no screens of their own. They are states of the screens above and use the shared patterns in section 5.10.

## 5. Screen Specs

Common layout (all screens): `AppBackground` behind everything. `TopBar` at the top (S-1 and S-9 have none). Content scrolls vertically in `GlassCard` groups with `space.lg` between groups and `space.screenMargin` side margins. `BottomActionBar` floats above the safe area on S-2, S-4, S-5, S-6, S-7, S-8 and S-9; content has bottom padding equal to the bar height so nothing is hidden. In S-5 to S-8 the `TopBar` shows the back control and the `StepIndicator` sits directly below it.

### 5.1 S-1 Launch

- Purpose: show the brand while the app starts (FR-1).
- Entry/Exit: entry on app start. Exit to S-2 automatically after the start work finishes, shown for at least 1.0 s and at most 2.0 s (proposed values, adjustable). Nothing is tappable.
- Layout: `AppBackground`; `LogoMark` (Large) centred, no text, no button, no loading text.
- Data shown: the logo only (FR-1).
- Actions: none.
- States:

| State | Behaviour |
| ----- | --------- |
| Default | Logo centred with a gentle scale-in (`motion.duration.long`). |
| Loading | Same as Default. Any start work happens behind the logo; no spinner is shown. |
| Empty | N/A: the screen shows no data. |
| Error | N/A: start never blocks here; data load failures are shown on S-2 (section 5.2). |
| Disabled | N/A: no controls. |
| Success | N/A: exit to S-2 is the only outcome. |

- Validation: none.
- Accessibility: the logo has the label `LOGO_LABEL`; the screen is announced once.

### 5.2 S-2 Home

- Purpose: entry point (FR-2).
- Entry/Exit: from S-1 and from S-9. Exits to S-3 (View products), S-5 (Place order), the Zalo app or the phone dialer.
- Layout, top to bottom: `LogoMark` (Small) with shop name in `type.title.large`; greeting in `type.body` inside a `GlassCard`; a row of two `ContactButton` (Zalo, Phone); `BottomActionBar` with `PrimaryButton` "Place order" above `SecondaryButton` "View products".
- Data shown: shop name, short greeting (both from shop data, no marker).
- Actions:

| Action | Result | FR |
| ------ | ------ | -- |
| Tap Zalo | Opens Zalo with the shop contact (AC-3). If it cannot open, `Toast` with `ERR_OPEN_ZALO`. | FR-2 |
| Tap Phone | Opens the dialer with the shop number (AC-3). If it cannot open, `Toast` with `ERR_OPEN_PHONE`. | FR-2 |
| Tap View products | Go to S-3. | FR-2, FR-3 |
| Tap Place order | Go to S-5 with no cake chosen. | FR-2 |

- States:

| State | Behaviour |
| ----- | --------- |
| Default | All six elements visible. |
| Loading | Shop information is being loaded: skeleton for name and greeting (`StateView` Loading); contact and order buttons visible but disabled. |
| Empty | N/A: shop information is required data; a missing value is treated as Error. |
| Error | Shop information could not be loaded: `StateView` Error with `HOME_ERR` and `COMMON_RETRY`; all four action buttons disabled (their targets need the same data). Technical question TQ-3 covers whether cached data may be used offline. |
| Disabled | Contact buttons are disabled while Loading and Error. The "Place order" and "View products" buttons follow the same rule. |
| Success | N/A: no submit on this screen. |

- Validation: none.

### 5.3 S-3 Product list

- Purpose: show the four cakes (FR-3).
- Entry/Exit: from S-2. Exit to S-4 (tap a card) or back to S-2.
- Layout: `TopBar` (large title `PRODUCTS_TITLE`, back); four `ProductCard` in a vertical list. No bottom bar (ordering starts from the detail view or from S-2, FR-4).
- Data shown per card: picture, name, short description, current price. Exactly four cards (AC-4).
- Actions: tap a card to open S-4 (FR-3, FR-4).
- States:

| State | Behaviour |
| ----- | --------- |
| Default | Four cards. |
| Loading | Four skeleton cards (`StateView` Loading). |
| Empty | N/A: the product set is fixed at four. Fewer than four returned is treated as Error. |
| Error | `StateView` Error with `PRODUCTS_ERR` and `COMMON_RETRY`. A single failed picture shows a placeholder icon in the image frame (label `PRODUCT_IMG_FAILED`) while the card stays tappable. |
| Disabled | N/A: cards are always tappable once shown. |
| Success | N/A: no submit. |

- Validation: none.

### 5.4 S-4 Cake detail

- Purpose: show one cake and start an order with it (FR-4).
- Entry/Exit: from S-3. Exit to S-5 (order button) or back to S-3.
- Layout: `TopBar` (inline title is the cake name, back); large picture (`radius.image`); in a `GlassCard`: name (`type.title.large`), description (`type.body`), price (`type.body.strong`, with `PRICE_EACH`); `BottomActionBar` with `PrimaryButton` `DETAIL_BTN_ORDER`.
- Data shown: picture, name, description, current price. No other attributes (none are in the PRD).
- Actions: tap `DETAIL_BTN_ORDER` opens S-5 with this cake at quantity 1, other cakes at 0 (AC-5).
- States:

| State | Behaviour |
| ----- | --------- |
| Default | As above. |
| Loading | Skeleton for picture and text if the data is not yet available (for example after a restore); the button is disabled. |
| Empty | N/A: a detail is reached only from an existing card. |
| Error | Picture failed: placeholder and `PRODUCT_IMG_FAILED`, button still enabled. Data failed: `StateView` Error with `PRODUCTS_ERR` and `COMMON_RETRY`. |
| Disabled | The order button is disabled while Loading or Data-failed. |
| Success | N/A: no submit. |

- Validation: none.

### 5.5 S-5 Order step 1: Choose cakes

- Purpose: choose a quantity for each of the four cakes (FR-5).
- Entry/Exit: from S-2 (no cake), S-4 (that cake at 1), or from S-6 and S-8 via back or Edit. Exit to S-6, or back to the previous screen.
- Layout: `TopBar` (`FLOW_TITLE`, back); `StepIndicator` ("Step 1 of 4", `STEP_LABEL` and `STEP1`); one `GlassCard` containing four rows: thumbnail, name, price (`type.body.strong`), `QuantityStepper`; a summary `GlassCard` with `QTY_TOTAL` and `QTY_SUBTOTAL`; `InlineMessage` (Info) with `QTY_MIN_HINT` when total is below MIN_QTY; `BottomActionBar` with `PrimaryButton` `COMMON_NEXT`.
- Data shown: for each cake name, price, quantity; total number of cakes; cakes subtotal (sum of price x quantity, BR-5).
- Actions:

| Action | Result | FR |
| ------ | ------ | -- |
| Plus / minus on a stepper | Quantity changes by 1; minimum 0. Totals update. | FR-5 |
| Tap `COMMON_NEXT` | Go to S-6. Enabled only when total is at least MIN_QTY. | FR-5, FR-10 |
| Back | Return to the previous screen (see section 3). | FR-15 |

- States:

| State | Behaviour |
| ----- | --------- |
| Default | Quantities as chosen; the hint `QTY_MIN_HINT` is visible while the total is below MIN_QTY. |
| Loading | Product names and prices not yet available: skeleton rows, steppers and Next disabled. |
| Empty | Total is 0 (nothing chosen): all steppers at 0, the hint is shown, Next disabled. This is the normal first state from "Place order". |
| Error | Products could not be loaded: `StateView` Error with `PRODUCTS_ERR` and `COMMON_RETRY`. |
| Disabled | Next is disabled while the total is below MIN_QTY (the hint explains why, AC-13); minus is disabled at 0. |
| Success | N/A: no submit. |

- Validation: rule MIN_QTY (BR-4) with message `ERR_MIN_QTY`, shown as the persistent hint `QTY_MIN_HINT` here and as a blocking message on S-8 (FR-10, AC-13). No upper limit in the UI beyond the remaining amount of the date (BR-4); see TQ-5 for a technical input bound.
- Note: when the customer changes quantities after choosing a date, S-6 re-checks the chosen date (section 5.6).

### 5.6 S-6 Order step 2: Date and time

- Purpose: choose the receiving date and one time slot (FR-6, FR-7).
- Entry/Exit: from S-5, or from S-7 and S-8 via back or Edit. Exit to S-7, or back to S-5.
- Layout: `TopBar`, `StepIndicator` (`STEP2`); `GlassCard` with title `DATE_TITLE`, range hint `DATE_HINT_RANGE`, and `DateGrid`; a legend line `DATE_LEGEND_FULL`; `GlassCard` with title `TIME_TITLE` and a vertical list of `SlotChip`; `InlineMessage` `NEXT_HINT_DATE_TIME` while one of the two is missing; `BottomActionBar` with `PrimaryButton` `COMMON_NEXT`.
- Data shown: months from today's month to the month of today + MAX_DAYS_AHEAD; the fixed list of time slots (`SLOT_LABEL`), identical for every date (AC-10).
- Date availability (display rules from the PRD, no new rules):
  - Available: today + LEAD_DAYS up to today + MAX_DAYS_AHEAD (inclusive) and remaining amount at least the order's total number of cakes (BR-1, BR-2, BR-8; AC-7, AC-8, AC-24).
  - Unavailable and visibly marked: dates before the lead time, after the horizon, and dates without enough remaining amount. Dates in the lead window and past the horizon use the dimmed style; full dates use the dimmed style with a diagonal strike. All unavailable dates are not focusable for selection and carry the spoken reasons `DATE_A11Y_*`.
  - The remaining amount number is not shown to the customer (not in any FR).
  - Choosing a slot never changes which dates are available (AC-10).
- Actions:

| Action | Result | FR |
| ------ | ------ | -- |
| Tap an available date | Date selected (single selection); tapping another replaces it. | FR-6 |
| Previous / next month control | Moves the calendar; disabled at the first and last month. | FR-6 |
| Tap a slot | Slot selected (single selection). | FR-7 |
| Tap `COMMON_NEXT` | Go to S-7. Enabled only when a date and a slot are both chosen. | FR-6, FR-7 |
| Back | Return to S-5, nothing lost. | FR-15 |

- States:

| State | Behaviour |
| ----- | --------- |
| Default | Calendar and slots shown; chosen date and slot highlighted with `color.primaryContainer`. |
| Loading | Availability of dates loading: calendar skeleton, slot list skeleton if slots are not yet available, Next disabled. |
| Empty | No date is selectable for this order size: calendar shown with every date unavailable, plus `InlineMessage` `DATE_EMPTY` and a `SecondaryButton` `DATE_EMPTY_ACTION` that returns to S-5. Next disabled. |
| Error | Availability or slots could not be loaded: `StateView` Error with `DATE_ERR` and `COMMON_RETRY`; Next disabled. |
| Disabled | Next is disabled until both date and slot are chosen (hint `NEXT_HINT_DATE_TIME`); unavailable dates are disabled. |
| Success | N/A: no submit. |

- Validation: a date and a slot are required to proceed (the Next button is disabled and the hint is shown, so no error is raised). If the customer returned to S-5, raised the quantity, and the chosen date no longer has enough room, the date selection is cleared, the slot choice is kept, and `InlineMessage` (Error) `DATE_CLEARED` is shown (supports FR-6, FR-10).

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
| Phone | Must be a valid number; format rules are a technical question (TQ-6, Q-T6) | `ERR_PHONE_INVALID` |
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
| Error | Two kinds, shown in the top `InlineMessage` (Error), flow data kept in both: (a) Rule not met, confirm blocked until fixed (FR-10): `ERR_MIN_QTY`, `ERR_DATE_CAPACITY` (also the message when another customer took the capacity, AC-9, AC-22), `ERR_DATE_LEAD`, `ERR_DATE_HORIZON`, `ERR_DISTRICT_UNSERVED`; each has an action button that opens the step to fix (S-5, S-6 or S-7, using `DATE_EMPTY_ACTION` for quantity and `ACTION_CHOOSE_DATE`, `ACTION_CHOOSE_DISTRICT`). (b) Not sent: `ERR_OFFLINE`, `ERR_SERVER` or `ERR_TIMEOUT` with `COMMON_RETRY`; no confirmation screen appears (AC-20). Pending: `MSG_PRICE_CHANGED` (TQ-4). |
| Disabled | Confirm is disabled while Loading and while a rule error is shown (kind a). After the customer fixes it and returns, confirm is enabled again. Confirm stays enabled after a kind b error so retry is possible. |
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

### 5.10 Shared error and offline patterns

| Situation | Where | Behaviour |
| --------- | ----- | --------- |
| Data load fails (shop info, products, availability, districts) | S-2, S-3, S-4, S-5, S-6, S-7 | `StateView` Error or `InlineMessage` with the screen's key and `COMMON_RETRY`. Retry reloads only the failed data; entered flow data stays. |
| No connection while loading | Same | Same pattern; the message names the network (`ERR_NETWORK_LOAD`). Nothing is entered into the order that depends on missing data. |
| No connection while sending | S-8 | `ERR_OFFLINE`, entered data kept, retry available (AC-20). |
| Server error or timeout while sending | S-8 | `ERR_SERVER` or `ERR_TIMEOUT`, entered data kept, retry available (FR-17). |
| Connection returns | Any | No automatic send. The customer taps retry. A visible load error retries on `COMMON_RETRY` only. |
| App goes to background and returns | S-5 to S-8 | Flow data kept while the app process lives. Restoration after the process ends is not specified (TQ-7). |

## 6. Platform Notes

Identical on both platforms unless listed. Technology below follows section 2; minimum OS versions are not decided here (TQ-1).

| Topic | iOS | Android |
| ----- | --- | ------- |
| UI technology | SwiftUI; Liquid Glass (`glassEffect` inside `GlassEffectContainer`, glass button styles) on iOS 26 and later | Jetpack Compose; Material 3 Expressive (`MaterialExpressiveTheme`, `ButtonGroup`, floating toolbar or flexible bottom app bar, `LoadingIndicator`) |
| Fallback | Before iOS 26: `material.fallback` with the same layout; also used when Reduce Transparency is on | Without blur support or with reduced transparency: `material.fallback` (opaque tonal surface) |
| Logo container | Rounded square | Organic blob shape |
| Top bar | Large title collapsing to inline, native back with swipe-back | Large flexible top app bar, system back and predictive back |
| Bottom action bar | Floating glass bar | Floating toolbar / flexible bottom app bar, stays above gesture or button navigation |
| District picker | Sheet with list | Modal bottom sheet with list |
| Steppers | Capsule with two buttons | `ButtonGroup` around a value |
| Loading | Skeleton, system spinner for the confirm button | Skeleton, `LoadingIndicator` for the confirm button |
| Zalo and phone | Open by URL scheme to Zalo and the `tel` scheme; the exact link forms and whether Zalo needs a store fallback are technical (TQ-2) | Same via intents |
| Haptics and motion | See section 7 | See section 7 |

## 7. Motion & Haptics

Standard tokens and feedback table: `design-system.md` section 4. Specific to this feature:

| Moment | Motion | Haptic |
| ------ | ------ | ------ |
| S-1 to S-2 | Logo cross-fades into the home layout, `motion.duration.long` | None |
| Between order steps | Native push and pop; `StepIndicator` segment fills with `motion.spring.standard` | None |
| Quantity change (S-5) | Value cross-fade; totals count with a short cross-fade | Selection (iOS), segment tick (Android) |
| Date or slot chosen (S-6) | Fill change | Selection / context click |
| Validation failure (S-7) and blocked confirm (S-8) | Message appears; field shakes once | Error notification / reject |
| Confirm tapped (S-8) | Button morphs to its loading form | Light impact / context click |
| Order received (S-9) | `StatusMark` plays with `motion.spring.bouncy`, order code fades in after 150 ms | Success notification / confirm |
| Reduce Motion / remove animations | All of the above become 150 ms cross-fades; blobs stay still | Haptics unchanged |

## 8. Content & Copy

All display text is Vietnamese. Data-source values (shop name, greeting, cake names and descriptions, district names, slot times) come from the shop data and are not listed.

| Key | Vietnamese text | Used on |
| --- | --------------- | ------- |
| `LOGO_LABEL` | Logo cửa hàng | S-1, S-2 (screen reader) |
| `HOME_BTN_ZALO` | Zalo | S-2, S-9 |
| `HOME_BTN_PHONE` | Gọi điện | S-2, S-9 |
| `HOME_BTN_PRODUCTS` | Xem sản phẩm | S-2 |
| `HOME_BTN_ORDER` | Đặt bánh | S-2 |
| `HOME_ERR` | Không tải được thông tin cửa hàng. Vui lòng kiểm tra kết nối mạng và thử lại. | S-2 |
| `ERR_OPEN_ZALO` | Không mở được Zalo. Bạn có thể gọi điện cho cửa hàng. | S-2, S-9 |
| `ERR_OPEN_PHONE` | Không mở được ứng dụng gọi điện. | S-2, S-9 |
| `ERR_NETWORK_LOAD` | Không có kết nối mạng. Vui lòng kiểm tra kết nối và thử lại. | S-3 to S-7 |
| `COMMON_RETRY` | Thử lại | all error states |
| `COMMON_BACK` | Quay lại | back control (screen reader label) |
| `COMMON_NEXT` | Tiếp tục | S-5, S-6, S-7 |
| `COMMON_EDIT` | Sửa | S-8 |
| `COMMON_LOADING` | Đang tải | loading states (screen reader) |
| `PRODUCTS_TITLE` | Sản phẩm | S-3 |
| `PRODUCTS_ERR` | Không tải được thông tin bánh. Vui lòng thử lại. | S-3, S-4, S-5 |
| `PRODUCT_IMG_FAILED` | Không tải được ảnh | S-3, S-4 |
| `PRICE_EACH` | {amount}/cái | S-3, S-4, S-5 |
| `DETAIL_BTN_ORDER` | Đặt bánh này | S-4 |
| `FLOW_TITLE` | Đặt bánh | S-5 to S-8 |
| `STEP_LABEL` | Bước {n}/4 | S-5 to S-8 |
| `STEP1` | Chọn bánh | S-5 |
| `STEP2` | Ngày và giờ nhận | S-6 |
| `STEP3` | Người nhận và địa chỉ | S-7 |
| `STEP4` | Xem lại đơn hàng | S-8 |
| `QTY_TOTAL` | Tổng số bánh: {n} | S-5 |
| `QTY_SUBTOTAL` | Tiền bánh: {amount} | S-5 |
| `QTY_MIN_HINT` | Đơn hàng cần ít nhất {min} bánh. | S-5 |
| `QTY_INC_A11Y` | Tăng số lượng {name} | S-5 |
| `QTY_DEC_A11Y` | Giảm số lượng {name} | S-5 |
| `QTY_VALUE_A11Y` | {name}, số lượng {n} | S-5 |
| `DATE_TITLE` | Chọn ngày nhận | S-6 |
| `DATE_HINT_RANGE` | Nhận bánh từ {from} đến {to}. | S-6 |
| `DATE_LEGEND_FULL` | Ngày gạch chéo không còn đủ chỗ cho đơn của bạn. | S-6 |
| `DATE_A11Y_SELECTED` | {date}, đã chọn | S-6 |
| `DATE_A11Y_FULL` | {date}, không còn đủ chỗ cho đơn này | S-6 |
| `DATE_A11Y_TOO_SOON` | {date}, chưa thể chọn vì cần đặt trước ít nhất {days} ngày | S-6 |
| `DATE_A11Y_TOO_FAR` | {date}, chưa thể chọn vì chỉ nhận đặt trước tối đa {max} ngày | S-6 |
| `DATE_EMPTY` | Không có ngày nào còn đủ chỗ cho đơn của bạn. Hãy giảm số lượng bánh. | S-6 |
| `DATE_EMPTY_ACTION` | Sửa số lượng | S-6, S-8 |
| `DATE_ERR` | Không tải được lịch nhận bánh. Vui lòng thử lại. | S-6 |
| `DATE_CLEARED` | Ngày bạn chọn không còn đủ chỗ cho đơn của bạn. Vui lòng chọn ngày khác. | S-6 |
| `TIME_TITLE` | Chọn giờ nhận | S-6 |
| `SLOT_LABEL` | {start} – {end} | S-6, S-8 |
| `NEXT_HINT_DATE_TIME` | Chọn ngày và giờ nhận để tiếp tục. | S-6 |
| `FIELD_NAME` | Họ và tên | S-7 |
| `FIELD_PHONE` | Số điện thoại | S-7 |
| `FIELD_ADDRESS` | Địa chỉ giao hàng | S-7 |
| `FIELD_DISTRICT` | Quận/huyện | S-7 |
| `DISTRICT_PLACEHOLDER` | Chọn quận/huyện | S-7 |
| `DISTRICT_FEE` | Phí giao hàng: {amount} | S-7 |
| `DISTRICT_ERR` | Không tải được danh sách khu vực giao hàng. | S-7 |
| `DISTRICT_EMPTY` | Hiện chưa có khu vực giao hàng nào. Vui lòng liên hệ cửa hàng. | S-7 |
| `FIELD_NOTE` | Ghi chú (không bắt buộc) | S-7 |
| `NOTE_COUNTER` | {n}/200 | S-7 |
| `ERR_NAME_REQUIRED` | Vui lòng nhập họ và tên. | S-7 |
| `ERR_PHONE_REQUIRED` | Vui lòng nhập số điện thoại. | S-7 |
| `ERR_PHONE_INVALID` | Số điện thoại không hợp lệ. | S-7 |
| `ERR_ADDRESS_REQUIRED` | Vui lòng nhập địa chỉ giao hàng. | S-7 |
| `ERR_DISTRICT_REQUIRED` | Vui lòng chọn quận/huyện. | S-7 |
| `ERR_NOTE_MAX` | Ghi chú tối đa 200 ký tự. | S-7 |
| `REVIEW_SEC_CAKES` | Bánh đã chọn | S-8 |
| `REVIEW_ITEM` | {name} × {n} | S-8 |
| `REVIEW_FEE` | Phí giao hàng | S-8 |
| `REVIEW_TOTAL` | Tổng cộng | S-8 |
| `REVIEW_DATE` | Ngày nhận | S-8 |
| `REVIEW_TIME` | Giờ nhận | S-8 |
| `REVIEW_NAME` | Người nhận | S-8 |
| `REVIEW_PHONE` | Số điện thoại | S-8 |
| `REVIEW_ADDRESS` | Địa chỉ giao hàng | S-8 |
| `REVIEW_NOTE` | Ghi chú | S-8 |
| `REVIEW_PRIVACY` | Chúng tôi chỉ dùng họ tên, số điện thoại và địa chỉ của bạn để giao đơn hàng này và liên hệ với bạn. | S-8 |
| `BTN_CONFIRM` | Xác nhận đơn hàng | S-8 |
| `BTN_SENDING` | Đang gửi đơn | S-8 |
| `ERR_MIN_QTY` | Đơn hàng cần ít nhất {min} bánh. Vui lòng thêm bánh. | S-8 |
| `ERR_DATE_CAPACITY` | Ngày {date} không còn đủ chỗ cho đơn của bạn. Vui lòng chọn ngày khác. | S-8 |
| `ERR_DATE_LEAD` | Ngày nhận phải sau ngày đặt ít nhất {days} ngày. Vui lòng chọn ngày khác. | S-8 |
| `ERR_DATE_HORIZON` | Chỉ nhận đặt trước tối đa {max} ngày. Vui lòng chọn ngày sớm hơn. | S-8 |
| `ERR_DISTRICT_UNSERVED` | Cửa hàng chưa giao đến khu vực này. Vui lòng chọn quận/huyện khác. | S-8 |
| `ACTION_CHOOSE_DATE` | Chọn ngày khác | S-8 |
| `ACTION_CHOOSE_DISTRICT` | Chọn khu vực khác | S-8 |
| `ERR_OFFLINE` | Đơn hàng chưa được gửi vì không có kết nối mạng. Thông tin của bạn vẫn được giữ lại. | S-8 |
| `ERR_SERVER` | Đơn hàng chưa được gửi do có lỗi. Thông tin của bạn vẫn được giữ lại. Vui lòng thử lại. | S-8 |
| `ERR_TIMEOUT` | Đơn hàng chưa được gửi vì mất quá nhiều thời gian. Thông tin của bạn vẫn được giữ lại. Vui lòng thử lại. | S-8 |
| `MSG_PRICE_CHANGED` | PENDING (see TQ-4). Proposed: Giá đã thay đổi. Vui lòng xem lại đơn hàng. | S-8 |
| `CONF_TITLE` | Đã nhận đơn hàng | S-9 |
| `CONF_CODE_LABEL` | Mã đơn hàng | S-9 |
| `CONF_CODE_A11Y` | Mã đơn hàng {code} | S-9 |
| `CONF_MESSAGE` | Cửa hàng đã nhận được đơn của bạn và sẽ liên hệ với bạn. Khi cần, bạn có thể nhắn Zalo hoặc gọi điện cho cửa hàng và cho biết mã đơn hàng. | S-9 |
| `CONF_BTN_HOME` | Về trang chủ | S-9 |

Copy check: no key contains payment wording (FR-19); `CONF_MESSAGE` says received and contact, not accepted (AC-25). Keys marked PENDING are not final.

## 9. Accessibility

Defaults from standard 02 apply: touch target at least 44 pt (iOS) and 48 dp (Android); contrast at least 4.5:1; every icon-only control labelled; layout survives the largest text size. Details:

| Topic | Specification |
| ----- | ------------- |
| Labels | Back (`COMMON_BACK`), steppers (`QTY_INC_A11Y`, `QTY_DEC_A11Y`, value `QTY_VALUE_A11Y`), contact buttons (their visible text), month controls (month name spoken), product image (cake name, or `PRODUCT_IMG_FAILED`), order code (`CONF_CODE_A11Y`, read character by character). |
| Calendar | Each day is one element with a spoken date and state (`DATE_A11Y_*`). Unavailable days are announced as unavailable with the reason. The grid is operable with a screen reader and keyboard or switch navigation. |
| Errors | Field errors are announced when they appear and are linked to the field; focus moves to the first invalid field after a failed Next (AC-12). Banners on S-8 are announced as alerts. |
| Dynamic type | Text scales to the largest iOS accessibility size and 200% Android. Rows wrap to two lines, steppers stack the value below the name if the row is too narrow, the calendar cell grows in height; content scrolls; the bottom bar never covers content (content bottom padding follows the bar height). |
| Contrast | Text on glass uses `color.text.primary` on `color.surface.glass`; if the blob behind lowers contrast below 4.5:1 the surface uses `color.surface.solid`. Primary button text `color.onPrimary` on `color.primary` is about 6.4:1 (estimate; to be measured). |
| Not colour alone | Selected and unavailable dates differ by fill, border and strike pattern, and by spoken state. |
| Motion | Reduce Motion and remove-animation settings turn all movement into 150 ms cross-fades. |
| Focus | Visible focus ring `color.focus` for external keyboards and switch control. |
| Language | The screen reader language for all text is Vietnamese. |

## 10. Traceability

FR to screens. "X" means the screen implements or shows the requirement.

| FR | S-1 | S-2 | S-3 | S-4 | S-5 | S-6 | S-7 | S-8 | S-9 | Notes |
| -- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ----- |
| FR-1 | X | | | | | | | | | Logo only, then S-2 |
| FR-2 | | X | | | | | | | | Name, greeting, Zalo, phone, two buttons |
| FR-3 | | | X | X | | | | | | Four cakes, picture, name, description, price |
| FR-4 | | | | X | X | | | | | Order button, quantity 1 |
| FR-5 | | | | | X | | | | | Quantity per cake |
| FR-6 | | | | | | X | | | | Date choice; unavailable dates not selectable |
| FR-7 | | | | | | X | | | | Fixed slot list |
| FR-8 | | | | | | | X | | | Name, phone, address, district |
| FR-9 | | | | | | | | X | | Review content |
| FR-10 | | | | | X | X | | X | | Blocking messages; hint on S-5; date check on S-6 |
| FR-11 | | | | | | | | X | X | Confirm then code and message |
| FR-12 | | | | | | | | | X | Zalo and phone buttons |
| FR-13 | | | | | | | X | | | Errors next to fields |
| FR-14 | X | X | X | X | X | X | X | X | X | All text Vietnamese, section 8 |
| FR-15 | | | | | X | X | X | X | | Back and Edit keep data |
| FR-16 | | | | | | | | X | | Confirm inert while sending |
| FR-17 | | | | | | | | X | | Not-sent message, data kept |
| FR-18 | | | | | | | X | X | | Note input, counter, shown on review |
| FR-19 | | X | X | X | X | X | X | X | X | Constraint: no payment text anywhere |

Non-FR items covered: privacy sentence before confirmation (PRD section 8, Privacy) on S-8; accessibility and performance (PRD section 8) in sections 5.8 and 9; AC-29 (no visible sample marker) in the global rules. ACs mapped to screens: AC-1 S-1; AC-2, AC-3 S-2; AC-4 S-3; AC-5 S-4 and S-5; AC-6 S-5, S-8; AC-7, AC-8, AC-10, AC-24 S-6; AC-9, AC-13, AC-22 S-8; AC-11, AC-12, AC-26 S-7; AC-14, AC-18, AC-19, AC-20 S-8; AC-15, AC-16, AC-17, AC-25 S-9; AC-21 all; AC-27 all.

Every FR is traced. No screen element is without an FR; the PRD items BR-1 to BR-12 appear only through the FRs above. AC-23 (price kept after change) and AC-28 (cancellation) have no UI.

## 11. Assets

- Mockups: reference only, private link recorded in the PRD header. The text of this document is authoritative.
- Pictures of the four cakes and the logo: fake placeholder images supplied with launch data; no real customer data in any asset. No exported images are stored in the repository yet.
- Icons: native system symbols on iOS and Material Symbols on Android (Zalo and phone icons: the Zalo brand mark use is a technical question, TQ-2).

## 12. Open Questions / Change log

Business questions: none. Copy is final except the key marked PENDING.

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| TQ-1 | Minimum iOS and Android versions (Liquid Glass needs iOS 26; Material 3 Expressive needs a Compose Material3 release that may still be alpha or experimental) | Decides how much fallback rendering is built (same as PRD Q-T3 and design-system DS-Q1) | No | technical | Open (architect) | |
| TQ-2 | How are Zalo and the dialer opened (link forms, behaviour when Zalo is not installed), and may the Zalo brand mark be used | AC-3, FR-2, FR-12 | No | technical | Open (architect) | |
| TQ-3 | May shop information and products be cached for offline display on S-2 to S-4, or must they always be loaded fresh | Error state of S-2 and S-3 (config source is Q-T2) | No | technical | Open (architect) | |
| TQ-4 | If a price changed between the review and the confirmation (BR-5, BR-6), is the order rejected with a re-review, or accepted at the reviewed price | Possible new message `MSG_PRICE_CHANGED` and S-8 behaviour | No | technical | Open (architect) | |
| TQ-5 | Is there a technical upper bound for one cake's quantity (input safety)? The UI assumes none besides date capacity, with a stepper capped at 99 only if the architect confirms | S-5 stepper behaviour | No | technical | Open (architect) | |
| TQ-6 | Phone number validation rules, maximum lengths of name and address, and order code format and length (display width of `OrderCodeDisplay`) | S-7 validation, S-9 layout (same as Q-T6) | No | technical | Open (architect) | |
| TQ-7 | Should the in-progress order survive the app being closed by the system | FR-15 scope on process death | No | technical | Open (architect) | |
| TQ-8 | Is a paid or third-party blur library allowed for Android below the version where native blur exists | Fallback cost (DS-Q2) | No | technical | Open (architect) | |

Assumptions: launch screen time 1.0 to 2.0 s; slots appear as a list and dates as a month grid; the district is chosen from a sheet; leaving the flow from step 1 discards flow data without a confirmation dialog (no FR asks for one).

### Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version, based on product/place-order.md v1.2. |
