# Place Order UI, part 9b: Test identifier deviations of the code (section 9.1)

[v1.5 | 2026-10-29] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Compares the canonical set in [part 9](09-accessibility-test-ids.md) section 9.1 with the code read on 2026-10-29: `ios/Shared/AccessibilityID.swift` and `android/app/src/main/kotlin/app/banh/customer/TestTags.kt`. No code was edited; forge-dev aligns the code (rename the constant value only, then the tests that use it). "ok" means the code already matches. "missing" means add the element and its identifier.

## S-5 to S-8 deviations

| Canonical identifier | iOS code | Android code |
| -------------------- | -------- | ------------ |
| `nav.back` | `nav.backButton`, rename | ok |
| `order.step`, `order.next`, `order.cakeRemovedNotice` | ok | ok |
| `order.title` | ok | missing, add on the step title |
| `order.qty.total` | `order.qtyTotal`, rename | ok |
| `order.qty.subtotal` | `order.qtySubtotal`, rename | ok |
| `order.qty.minHint` | `order.qtyMinHint`, rename | ok |
| `order.qty.<id>.inc` | `order.qty.inc.<id>`, rename | ok |
| `order.qty.<id>.dec` | `order.qty.dec.<id>`, rename | ok |
| `order.qty.<id>.value` | `order.qty.value.<id>`, rename | ok |
| `order.date.month` | `order.date.monthTitle`, rename | ok |
| `order.date.previous` | `order.date.monthPrevious`, rename | ok |
| `order.date.next` | `order.date.monthNext`, rename | ok |
| `order.date.<yyyy-MM-dd>` | ok | ok |
| `order.date.rangeHint` (`DATE_HINT_RANGE`) | ok | missing, add |
| `order.date.hint` (`NEXT_HINT_DATE_TIME`) | `order.nextHint`, rename | ok |
| `order.date.empty` | `order.date.emptyNotice`, rename | ok |
| `order.date.emptyAction` | ok | ok |
| `order.date.cleared` | `order.date.clearedNotice`, rename | ok |
| `order.date.loading` | missing, add on the calendar skeleton | ok |
| `order.slot.<slotId>` | ok | ok |
| `order.field.name` / `phone` / `address` / `district` / `note` | ok | ok |
| `order.error.<field>` | ok | ok (`order.error.note` also exists as `ORDER_NOTE_ERROR`, same string) |
| `order.note.counter` | `order.noteCounter`, rename | ok |
| `order.district.fee` | `order.districtFee`, rename | ok |
| `order.district.error` | `order.districtError`, rename | ok |
| `order.district.empty` | `order.districtEmpty`, rename | ok |
| `order.district.row.<districtId>` | ok | ok |
| `review.total` / `fee` / `date` / `time` | ok | `order.review.*`, rename (drop `order.`) |
| `review.name` / `phone` / `address` / `note` | ok | `order.review.*`, rename |
| `review.privacy` / `review.confirm` | ok | `order.review.*`, rename |
| `review.item.<id>` | ok | `order.review.item.<id>`, rename |
| `review.edit.cakes` | ok | `order.review.editCakes`, rename |
| `review.edit.date` | ok | `order.review.editDelivery`, rename |
| `review.edit.recipient` | ok | `order.review.editRecipient`, rename |
| `review.message` | ok | `order.review.issue`, rename |
| `review.messageAction` | ok | missing, add on the banner action button |
| `state.toast` | ok | missing, add if a toast exists (S-2 link failure `ERR_OPEN_*`) |
| `state.empty`, `state.error`, `state.retry` | ok | ok |

## Other notes for forge-dev

- Android `TestTags.kt` says "iOS uses the same strings": that is not true until the renames above are done.
- The Android comment on `ORDER_DATE_HINT` is the `NEXT_HINT_DATE_TIME` message; the range sentence is a separate element (`order.date.rangeHint`).
- `iOS AccessibilityID.orderTitle` marks the step title; Android needs the same on its header title.
- Copy deviations (not identifiers): `DETAIL_BTN_ORDER` must read "Đặt bánh" on both platforms (the iOS String Catalog and Android `detail_btn_order` still say "Đặt bánh này"); `NOTE_COUNTER` and `ERR_NOTE_MAX` take {max} from `settings.note_max_length` (fallback 200), not a literal 200 (Android already passes the number; check iOS); `DATE_A11Y_AVAILABLE` and `DATE_SPOKEN` apply to both platforms (iOS has no such constant in `OrderStrings.swift`).
