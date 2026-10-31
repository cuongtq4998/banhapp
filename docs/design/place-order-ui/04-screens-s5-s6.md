# Place Order UI, part 4: Screen specs S-5 Choose cakes and S-6 Date and time (sections 5.5, 5.6)

[v1.4 | 2026-10-27] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Content unchanged from v1.3; section numbers are the original ones.

### 5.5 S-5 Order step 1: Choose cakes

- Purpose: choose a quantity for each active cake (FR-5, BR-13). [v1.2 | 2026-10-26]
- Entry/Exit: from S-2 (no cake, or the restored draft with its quantities when a saved draft exists, [v1.1 | 2026-10-25] no prompt), S-4 (new draft, that cake at 1), or from S-6 and S-8 via back or Edit. Exit to S-6, or back to the previous screen.
- Layout: `TopBar` (`FLOW_TITLE`, back); `StepIndicator` ("Step 1 of 4", `STEP_LABEL` and `STEP1`); one `GlassCard` containing one row per active cake (1 to 4 rows, [v1.2 | 2026-10-26] no blank or disabled row for a hidden cake; the card simply gets shorter): thumbnail, name, price (`type.body.strong`), `QuantityStepper`; a summary `GlassCard` with `QTY_TOTAL` and `QTY_SUBTOTAL`; `InlineMessage` (Info) with `QTY_MIN_HINT` when total is below MIN_QTY; `BottomActionBar` with `PrimaryButton` `COMMON_NEXT`.
- Data shown: for each cake name, price, quantity; total number of cakes; cakes subtotal (sum of price x quantity, BR-5).
- Actions:

| Action | Result | FR |
| ------ | ------ | -- |
| Plus / minus on a stepper | Quantity changes by 1; minimum 0, [v1.1 | 2026-10-25] maximum 99 per cake. At 99 the plus button is disabled with no message. Totals update. | FR-5 |
| Tap `COMMON_NEXT` | Go to S-6. Enabled only when total is at least MIN_QTY. | FR-5, FR-10 |
| Back | Return to the previous screen (see section 3). | FR-15 |

- States:

| State | Behaviour |
| ----- | --------- |
| Default | Quantities as chosen; the hint `QTY_MIN_HINT` is visible while the total is below MIN_QTY. |
| Loading | Product names and prices not yet available: skeleton rows, steppers and Next disabled. |
| Empty | Total is 0 (nothing chosen): all steppers at 0, the hint is shown, Next disabled. This is the normal first state from "Place order". [v1.2 | 2026-10-26] Zero active cakes (reached when S-2 had no answer yet or a stale cache): `StateView` Error layout with `PRODUCTS_EMPTY` and `COMMON_RETRY`; no rows, no summary, Next disabled; the draft data is kept. After a retry that finds an active cake the rows appear. |
| Cake removed [v1.2 | 2026-10-26] | A cake in the draft (restored or in progress) is not in the refreshed active list, or S-8 sent the customer back with `ERR_PRODUCT_UNAVAILABLE`: its row is not shown, its quantity is dropped from the totals, an `InlineMessage` (Info) `ORDER_CAKE_REMOVED` (with the cake name) appears above the rows until the customer changes a quantity or leaves the step; quantities of the other cakes and all other flow data (date, slot, recipient) are kept. If the date no longer has room for the smaller total nothing changes, since a smaller order only needs less room; if the total falls below MIN_QTY the normal hint shows. |
| Error | [v1.1 | 2026-10-25] Products could not be loaded and there is no cache: `StateView` Error with `PRODUCTS_ERR` and `COMMON_RETRY`. With a cache, cached prices are shown and a failed refresh is silent (the server price check on confirm is the final guard, ADR-0010). |
| Disabled | Next is disabled while the total is below MIN_QTY (the hint explains why, AC-13); minus is disabled at 0; [v1.1 | 2026-10-25] plus is disabled at 99 for that cake, silently (input-safety bound, ADR-0009; the limit is configuration `max_qty_per_cake`, not shown). |
| Success | N/A: no submit. |

- Validation: rule MIN_QTY (BR-4) with message `ERR_MIN_QTY`, shown as the persistent hint `QTY_MIN_HINT` here and as a blocking message on S-8 (FR-10, AC-13). [v1.1 | 2026-10-25] No business upper limit beyond the remaining amount of the date (BR-4); the stepper stops at 99 per cake as an input bound (ADR-0009), without a message.
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
