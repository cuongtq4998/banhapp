# Admin Orders UI, part 10: Accessibility and test identifiers (section 9)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.1 | 2026-10-31]

## 9. Accessibility

Defaults of standard 02 apply: touch target 44 pt (iOS) and 48 dp (Android) at least; text contrast 4.5:1; every icon-only control labelled; layout survives the largest text size. The language of all text for screen readers is Vietnamese.

| Topic | Specification |
| ----- | ------------- |
| Icon-only controls | Back (`A_BACK`), staff account button (`A_ACCOUNT_A11Y`), add buttons on S-A10 (`A_ADD_SLOT`, `A_ADD_DISTRICT`), search clear (`A_RESET`), picker image clear (`A_IMG_REMOVE_PICK`). [v1.1 | 2026-10-31] |
| Status and marks | `StatusBadge` always carries the word. The `DueMark` is text ("Giao hôm nay", "Quá hạn 2 ngày") plus an icon, never red alone; it is read as part of the row. Hidden cakes say "Đã ẩn", off accounts "Đã tắt", the selected status chip is announced as selected. [v1.1 | 2026-10-31] |
| Order row | One element: code, status, customer, delivery date and slot, due mark, cakes, total, district, in that order; trait button; hint `A_ROW_HINT_A11Y`. |
| Tab badge | Read as `A_TAB_BADGE_A11Y` on the Orders tab ("3 đơn cần xử lý"); a changed number after refresh is announced politely; "99+" is read "hơn 99". [v1.1 | 2026-10-31] |
| Code field | `OtpField` is one text input labelled `A_CODE_FIELD_A11Y`; the six cells are hidden from the screen reader; error text is announced as an alert; the resend countdown announces at 10 s steps and when enabled. |
| Forms | Each field has a visible label above it; the error is announced and linked to the field; focus moves to the first invalid field after a failed Save. The counter is read once on focus. |
| Filters | The status chips are a single-choice group ("1 of 6"); the date chip announces its current value; the date menu items are plain menu items. [v1.1 | 2026-10-31] |
| Dialogs and sheets | Focus moves into the sheet or dialog; the destructive choice is never the default focus; back closes without acting. The reason list is a single-selection group announced "n of 4". [v1.1 | 2026-10-31] |
| Dynamic type | Text scales to the largest iOS accessibility size and 200% on Android. Rows wrap; the two-button action bar stacks vertically when a label wraps; chips keep scrolling; the due mark moves under the date when narrow; nothing truncates a code, price, e-mail or message. |
| Contrast | Text on glass uses `color.text.primary` on `color.surface.glass`, else `color.surface.solid`. Status text, `color.due.text` on `color.due.fill`, white on `color.tabBadge.fill` and `color.destructive` on glass shall be measured. |
| Motion | `motion.reduced` turns shakes and slides into 150 ms cross-fades. |
| Focus and keyboard | Visible `color.focus` ring; Tab order follows reading order; Enter submits a valid form. |
| Privacy | The app preview in the task switcher hides customer data (iOS: blur snapshot on background; Android: secure window flag on S-A3 and S-A4) (BR-7, AC-45; TQ-D4). |

## 9.1 Test identifiers

One list for both platforms: iOS `accessibilityIdentifier` and Android `Modifier.testTag` use the identical string. UI tests select by identifier only. `<id>` is the server id of the item; `<code>` the order code. Prefix `admin.`. Removed in v1.1: `admin.signin.recovery`, `admin.recovery.*`, `admin.orders.newCount`, `.lastUpdated`, `.notif*`, `admin.date.*` (sheet), `admin.detail.history*`, `admin.cancel.reason.full`, `admin.settings.row.slots/districts/devices/backup/backupReminder`, `admin.devices.*`, `admin.backup.*`, `admin.account.devices`.

| Identifier | Element | Screen |
| ---------- | ------- | ------ |
| `admin.signin.email` / `.send` / `.error` / `.banner` | E-mail field, send button, error text, session banner | S-A1 |
| `admin.code.field` / `.submit` / `.resend` / `.changeEmail` / `.error` | Code field, sign-in button, resend, change e-mail, error | S-A2 |
| `admin.orders.title` / `.search` / `.accountButton` / `.badge` | Header items; staff header number | S-A3 |
| `admin.orders.filter.todo` / `.new` / `.confirmed` / `.completed` / `.cancelled` / `.all` / `.date` | Status chips and date chip | S-A3 |
| `admin.orders.date.all` / `.today` / `.tomorrow` / `.one` | Date menu items (the picker is native) | S-A3 |
| `admin.orders.list` / `.row.<code>` / `.due.<code>` / `.skeleton` / `.empty` / `.error` / `.offline` / `.loadMoreError` / `.searchMin` | List, due mark, states | S-A3 |
| `admin.tab.orders` / `admin.tab.orders.badge` / `admin.tab.settings` | Tab bar items and the red number | S-A3, S-A6 |
| `admin.detail.code` / `.status` / `.due` / `.customer` / `.phone` / `.call` / `.zalo` / `.address` | Detail header and customer | S-A4 |
| `admin.detail.delivery` / `.cakes` / `.cake.<index>` / `.fee` / `.total` / `.note` / `.reason` / `.lastChanged` | Detail cards | S-A4 |
| `admin.detail.confirm` / `.complete` / `.cancel` / `.completeYes` / `.completeBack` / `.conflict` / `.error` / `.gone` | Actions and messages | S-A4 |
| `admin.cancel.reason.customer` / `.cannotDeliver` / `.noContact` / `.spam` / `.confirm` / `.back` | Cancel sheet | S-A5 |
| `admin.settings.row.cakes` / `.rules` / `.delivery` / `.shop` / `.staff` / `.signOutOthers` / `.signOutOthersYes` / `.signOut` / `.signOutYes` | Five rows and sign-out buttons | S-A6 |
| `admin.cakes.add` / `.count` / `.row.<id>` / `.full` | Cake list | S-A7 |
| `admin.cakeForm.image` / `.change` / `.name` / `.desc` / `.price` / `.active` / `.save` / `.progress` / `.cancel` / `.remove` / `.removeYes` / `.error.<field>` | Cake form (add and edit) | S-A8 |
| `admin.rules.limit` / `.lead` / `.min` / `.save` / `.warnDialog` / `.warnConfirm` / `.error.<field>` | Ordering | S-A9 |
| `admin.delivery.district.add` / `.district.row.<id>` / `.district.toggle.<id>` / `.district.name` / `.district.fee` / `.district.save` | Districts | S-A10 |
| `admin.delivery.slot.add` / `.slot.row.<id>` / `.slot.toggle.<id>` / `.slot.start` / `.slot.end` / `.slot.save` / `.error` | Slots | S-A10 |
| `admin.shop.name` / `.greeting` / `.phone` / `.zalo` / `.save` / `.error.<field>` | Shop info | S-A11 |
| `admin.staff.add` / `.count` / `.row.<id>` / `.deactivate` / `.deactivateYes` / `.reactivate` | Staff list and detail | S-A12 |
| `admin.staffAdd.name` / `.email` / `.save` / `.error.<field>` | Add staff sheet | S-A12 |
| `admin.account.name` / `.email` / `.signOutOthers` / `.signOutOthersYes` / `.signOut` / `.signOutYes` | Account sheet | S-A13 |
| `admin.toast` / `admin.nav.back` / `admin.discard.confirm` / `admin.discard.keep` | Shared | all |
