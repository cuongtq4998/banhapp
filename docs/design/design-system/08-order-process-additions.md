# Design system, part 8: Order process components

Part of [design-system.md](../design-system.md). Version 0.2 [v0.2 | 2026-11-02]. Components added by admin-orders parts 12 and 13 and place-order part 13 (Draft). Tokens come from parts 2 to 4; no new tokens.

## OrderStepper

- Five rows: Received, Processing, Delivery date scheduled, Delivery started, Finished. Read-only. Variants: `admin` (inside the detail card, secondary text next to the scheduled row shows the expected date) and `customer` (inside a tracking card, more compact, same five names with `T_STEP_*` keys).
- States per row: done (filled circle with check, `color.brand`), current (ring with dot, bold label, text "current"), next (grey outline). Cancelled orders do not use the stepper.
- Accessibility: one element per row, "step n of 5, name, state". Dynamic type: rows wrap. Reduced motion: marker fades. Native base: SwiftUI `VStack` of `Label`; Compose `Column`. Not interactive.

## DateRangePickerRow

- A graphical native date picker limited to a range (today to today + 7 for the expected date), disabled days greyed, with a caption naming the first and last allowed date and a text line of the chosen date with weekday. Native base: iOS `DatePicker` graphical with `in:`; Android Material 3 `DatePicker` with `SelectableDates`. The range comes from the server today (shop time zone Asia/Ho_Chi_Minh), not the device clock; the component takes `minDate`, `maxDate` and `initialDate`.
- States: default, date chosen, unchanged (host disables save), range error shown by the host as `InlineMessage`.

## FeeEntrySheet

- A large-detent sheet with: read-only reference rows (previous fee in correction mode), one whole-dong `TextField` (number pad, suffix, range 0 to 10 000 000, 0 allowed), summary rows updating while typing (cakes total, fee, amount to collect), pinned bottom bar. Modes: `start` (S-A15, no history, empty field) and `correct` (S-A16, shows previous fee, same-value check). Validation on confirm, the button stays enabled.
- States: default, loading, field error, conflict (sheet closes, host shows message), offline. Keyboard: content scrolls above it, bar pinned.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 0.2 | 2026-11-02 | OrderStepper (admin and customer variants), DateRangePickerRow, FeeEntrySheet added. |
