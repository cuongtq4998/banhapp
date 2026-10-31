# Design System, part 7: Admin app additions (tokens and components)

[v1.5 | 2026-10-31] Part of the split design system; index: [design-system.md](../design-system.md). Added for the Admin app (first consumer: [admin-orders-ui.md](../admin-orders-ui.md)). The Admin app is a separate app on iOS and Android with the same visual language, so every token and component of parts 1 to 6 applies unchanged. This part only adds what the admin screens need. Contrast values are estimates and shall be re-measured on built screens.

## 7.1 New tokens [v1.5 | 2026-10-31]

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `color.status.new.fill` | Badge fill, status New | #FFF1CC | #FFF1CC |
| `color.status.new.text` | Badge text, status New (about 8:1 on the fill, estimate) | #5C4400 | #5C4400 |
| `color.status.confirmed.fill` | Badge fill, status Confirmed | #D4EBDB | `color.primaryContainer` (#A8F0BC) |
| `color.status.confirmed.text` | Badge text, status Confirmed | `color.accentText` | `color.onPrimaryContainer` |
| `color.status.completed.fill` | Badge fill, status Completed | rgba(20,35,26,0.08) | rgba(20,32,26,0.08) |
| `color.status.completed.text` | Badge text, status Completed | `color.text.secondary` | `color.text.secondary` |
| `color.status.cancelled.fill` | Badge fill, status Cancelled | `color.errorContainer` | `color.errorContainer` |
| `color.status.cancelled.text` | Badge text, status Cancelled | `color.destructive` | `color.destructive` |
| `type.badge` | Status badge, count pill | 12 pt Bold 700 (board 11 pt is raised for legibility), uppercase off | 12 sp Bold 700 |
| `type.code` | One-time code digit, order code in list row | 24 pt SemiBold 600, monospaced digits (order code in a row: 15 pt Bold 700) | 24 sp Medium 500, tabular figures (row code: 15 sp Bold 700) |
| `size.otpCell` | One cell of a code field | 44 x 52 pt, gap 8 pt, `radius.field` 16 pt | 48 x 56 dp, gap 8 dp, 16 dp radius |
| `size.imagePreview` | Cake picture in the add-cake form | 180 pt high, full card width, `radius.image` | 180 dp high, full card width, `radius.image` |
| `size.badgeHeight` | Status badge height | 24 pt, capsule, 10 pt horizontal padding | 24 dp, capsule, 10 dp horizontal padding |

## 7.2 New components [v1.5 | 2026-10-31]

| Component | Purpose | Variants | States | iOS mapping | Android mapping |
| --------- | ------- | -------- | ------ | ----------- | --------------- |
| `StatusBadge` | Order status next to the code | New, Confirmed, Completed, Cancelled; Active, Hidden (cakes), Active, Off (accounts, slots, districts) use the Confirmed and Completed styles | Static | Capsule, `type.badge`, status tokens; the word is always shown (never colour alone) | Same |
| `OrderRow` | One order in the list | Default | Default, Pressed, Skeleton | `GlassCard` tappable (`radius.card`, `space.cardPadding` 12 pt): line 1 code (`type.code`) and `StatusBadge` at the end, line 2 customer name (`type.list.name`), line 3 date and slot (`type.body`), line 4 cakes, total, district (`type.body.strong`); bare chevron. Wraps at large text | Same card, chevron in a 40 dp `color.primaryContainer` badge as `ProductCard` |
| `FilterChip` | Status filter, multi-select | Selected, Unselected | Default, Pressed, Disabled | Capsule 44 pt high; selected = filled `color.primary` (section 2.8 selected chip); unselected = `color.surface.chip` | Same, 48 dp high |
| `CountPill` | Number of New orders, "n/12", "n/30" | One | Default | Capsule `type.badge` on `color.surface.chip` | Same |
| `OtpField` | Six-digit code entry | One field (6 visible cells over one hidden text input) | Empty, Filling, Filled, Error, Disabled | Cells of `size.otpCell`; `type.code`; error = `color.error` border and shake (section 4); text content type one-time code; number pad | Same; paste fills all cells |
| `SettingsRow` | Row that opens a sub-screen | With value, without value, with attention dot | Default, Pressed | Row inside a `GlassCard`: leading icon, label (`type.list.name`), value (`type.body`, `color.text.secondary`), chevron; at least 56 pt high | Same, at least 56 dp |
| `ToggleRow` | Active/hidden/on/off switch | Switch at the end | On, Off, Disabled, Pending | Row with the native `Toggle`; `color.primary` when on | Row with the Material `Switch` |
| `ImagePickerField` | Choose and show the cake picture | Empty, Chosen, Uploading, Failed | Default, Error | `GlassCard` with a dashed-edge placeholder `color.image.placeholder`, icon and `A_IMG_PICK`; chosen = preview `size.imagePreview` and "Change" text button; system photo picker | Same with the Android photo picker |
| `ConfirmDialog` | Confirm a destructive or final action; names the item | Destructive (confirm text `color.destructive`), Neutral | Default, Loading | System alert (two buttons, cancel on the left, bold on the safe choice) | Material alert dialog |
| `ReasonList` | Choose one cancel reason | Five radio rows | Unselected, Selected | Sheet list, rows at least 52 pt, check mark at the end | Modal bottom sheet, radio buttons, rows at least 56 dp |
| `DeviceRow` | One signed-in device | This device, Other device | Default, Revoking | `GlassCard` row: device name (`type.list.name`), account name (owner view), last used (`type.caption`), `A_DEVICE_THIS` pill or `SecondaryButton` "Revoke" | Same |
| `AccountRow` | One staff or owner account | Owner, Staff active, Staff off | Default, Pressed | `GlassCard` row: name, e-mail (`type.caption`), `StatusBadge`, chevron (staff only) | Same |
| `HistoryTimeline` | Status history of an order | Entries newest at the bottom | Default | Vertical list in a `GlassCard`: dot, "old to new" text, account name, date and time, reason line for a cancellation | Same |
| `BannerAction` | `InlineMessage` with one text button | Info, Warning | Visible, dismissed | `InlineMessage` plus a trailing text button (`type.label`) | Same |
| `AdminTabBar` | Two tabs (orders, settings), owner only | Selected, Unselected, Attention dot | Default | Native `TabView` (Liquid Glass tab bar on iOS 26; `material.fallback` bar on iOS 17 to 25) | `NavigationBar` with glass or `color.surface.solid` fill, same two destinations |

## 7.3 Notes [v1.5 | 2026-10-31]

- The board shows a custom floating glass pill for the tab bar (iOS, 40 pt from the sides, tabs 56 pt high, selected tab gradient). The native tab bar is used instead so that iOS 26 gives the system glass behaviour; the pill is a visual reference only. Android did not have a tab bar on the board.
- `BottomActionBar` holds two buttons side by side in the admin app (already allowed in part 5): the left one `SecondaryButton` (destructive text `color.destructive` for cancel), the right one `PrimaryButton`.
- Haptics for the new components reuse section 4: status change success = Notification success / Confirm; refused change = Notification error / Reject; switch toggle = Selection / Segment tick.
