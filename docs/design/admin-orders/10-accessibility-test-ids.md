# Admin Orders UI, part 10: Accessibility and test identifiers (section 9)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31]

## 9. Accessibility

Defaults of standard 02 apply: touch target 44 pt (iOS) and 48 dp (Android) at least; text contrast 4.5:1; every icon-only control labelled; layout survives the largest text size. The language of all text for screen readers is Vietnamese.

| Topic | Specification |
| ----- | ------------- |
| Icon-only controls | Back (`A_BACK`), staff account button (`A_ACCOUNT_A11Y`), add buttons on S-A11 and S-A12 (`A_ADD_SLOT`, `A_ADD_DISTRICT`), search clear (`A_RESET`), banner close (`A_DISMISS`), picker image clear (`A_IMG_REMOVE_PICK`). |
| Status | `StatusBadge` always carries the word; it is read as part of the row. State is never colour alone: Hidden cakes also say "Đã ẩn", off accounts say "Đã tắt", the selected filter chip is announced as selected. |
| Order row | One element: code, status, customer, delivery date and slot, cakes, total, district, in that order; trait button; the hint is `A_ROW_HINT_A11Y`. |
| Code field | `OtpField` is one text input with the label `A_CODE_FIELD_A11Y`, not six; the six cells are hidden from the screen reader; the value is read digit by digit; error text is announced as an alert; resend countdown announces at 10 s steps and when enabled. |
| Forms | Each field has a visible label above it; the error is announced when it appears and is linked to the field; focus moves to the first invalid field after a failed Save. The counter ("120/300") is read once on focus. |
| Lists and counts | New count is read as "Mới: n" at the top; a new count after refresh is announced politely. Paging loads announce nothing; a failed page announces `A_LOAD_MORE_FAILED`. |
| Dialogs and sheets | Focus moves into the sheet or dialog; the destructive choice is never the default focus; Escape/back closes without acting. The reason list is a single-selection group announced as "n of 5". |
| Dynamic type | Text scales to the largest iOS accessibility size and 200% on Android. Rows wrap to more lines; the two-button action bar stacks the buttons vertically when a label wraps; chip rows keep scrolling; the status badge moves under the code when the row is narrow; nothing truncates a code, price, e-mail or message (e-mails wrap by character). |
| Contrast | Text on glass uses `color.text.primary` on `color.surface.glass`, else `color.surface.solid`. Status text on status fills is estimated at 6:1 or more and shall be measured; the destructive text `color.destructive` on glass shall be measured. |
| Motion | `motion.reduced` turns shakes and slides into 150 ms cross-fades. |
| Focus and keyboard | Visible `color.focus` ring for external keyboard and switch access; Tab order follows reading order; Enter submits a form with a valid state. |
| Privacy | The app preview in the task switcher hides customer data (iOS: blur snapshot on background; Android: secure window flag on S-A4 and S-A6) (BR-15; confirm with TQ-D4). |
| Notifications | Text is short and has no personal data, so lock-screen reading is safe. |

## 9.1 Test identifiers

One list for both platforms: iOS `accessibilityIdentifier` and Android `Modifier.testTag` use the identical string. UI tests select by identifier only, never by visible text. A tag goes on the element that is tapped or asserted. `<id>` is the server id of the item; `<code>` the order code. Prefix `admin.` keeps the set apart from the Customer app set.

| Identifier | Element | Screen |
| ---------- | ------- | ------ |
| `admin.signin.email` / `.send` / `.recovery` / `.error` / `.banner` | E-mail field, send button, recovery link, error text, session banner | S-A1 |
| `admin.code.field` / `.submit` / `.resend` / `.changeEmail` / `.error` | Code field, sign-in button, resend, change e-mail, error | S-A2 |
| `admin.recovery.email` / `.send` / `.codeOwner` / `.codeBackup` / `.submit` / `.error` | Fields and buttons | S-A3 |
| `admin.orders.title` / `.newCount` / `.lastUpdated` / `.search` / `.accountButton` | Header items | S-A4 |
| `admin.orders.filter.all` / `.new` / `.confirmed` / `.completed` / `.cancelled` / `.date` | Filter chips | S-A4 |
| `admin.orders.list` / `.row.<code>` / `.skeleton` / `.empty` / `.error` / `.offline` / `.loadMoreError` | List and states | S-A4 |
| `admin.orders.notifHint` / `.notifHintOpen` / `.notifPrime` / `.notifAllow` / `.notifLater` | Notification card and hint | S-A4 |
| `admin.date.all` / `.today` / `.tomorrow` / `.one` / `.range` / `.from` / `.to` / `.apply` / `.reset` | Date sheet | S-A5 |
| `admin.detail.code` / `.status` / `.customer` / `.phone` / `.call` / `.zalo` / `.address` | Detail header and customer | S-A6 |
| `admin.detail.delivery` / `.cakes` / `.cake.<index>` / `.fee` / `.total` / `.note` / `.reason` / `.history` / `.historyEntry.<index>` | Detail cards | S-A6 |
| `admin.detail.confirm` / `.complete` / `.cancel` / `.completeYes` / `.completeBack` / `.conflict` / `.error` / `.gone` | Actions and messages | S-A6 |
| `admin.cancel.reason.customer` / `.full` / `.cannotDeliver` / `.noContact` / `.spam` / `.confirm` / `.back` | Cancel sheet | S-A7 |
| `admin.settings.row.shop` / `.rules` / `.slots` / `.districts` / `.cakes` / `.staff` / `.devices` / `.backup` / `.signOut` / `.backupReminder` | Settings rows | S-A8 |
| `admin.tab.orders` / `admin.tab.settings` | Tab bar items | S-A4, S-A8 |
| `admin.shop.name` / `.greeting` / `.phone` / `.zalo` / `.save` / `.error.<field>` | Shop info | S-A9 |
| `admin.rules.limit` / `.lead` / `.min` / `.save` / `.warnDialog` / `.warnConfirm` / `.error.<field>` | Ordering rules | S-A10 |
| `admin.slots.add` / `.row.<id>` / `.toggle.<id>` / `.sheet.start` / `.sheet.end` / `.sheet.save` / `.error` | Slots | S-A11 |
| `admin.districts.add` / `.row.<id>` / `.toggle.<id>` / `.sheet.name` / `.sheet.fee` / `.sheet.save` / `.error` | Districts | S-A12 |
| `admin.cakes.add` / `.count` / `.row.<id>` / `.full` | Cake list | S-A13 |
| `admin.cakeEdit.image` / `.name` / `.desc` / `.price` / `.active` / `.save` / `.remove` / `.removeYes` / `.error.<field>` | Edit cake | S-A14 |
| `admin.cakeAdd.image` / `.change` / `.name` / `.desc` / `.price` / `.save` / `.progress` / `.cancel` / `.error.<field>` | Add cake | S-A15 |
| `admin.staff.add` / `.count` / `.row.<id>` / `.deactivate` / `.deactivateYes` / `.reactivate` | Staff | S-A16 |
| `admin.staffAdd.name` / `.email` / `.save` / `.error.<field>` | Add staff | S-A17 |
| `admin.devices.row.<id>` / `.revoke.<id>` / `.revokeYes` / `.recoveryBanner` / `.this` | Devices | S-A18 |
| `admin.account.name` / `.email` / `.devices` / `.signOut` / `.signOutYes` | Account | S-A19 |
| `admin.backup.current` / `.email` / `.send` / `.code` / `.confirm` / `.error` | Backup e-mail | S-A20 |
| `admin.toast` / `admin.nav.back` / `admin.discard.confirm` / `admin.discard.keep` | Shared | all |
