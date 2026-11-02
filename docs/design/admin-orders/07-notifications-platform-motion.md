# Admin Orders UI, part 7: Notifications, shared patterns, platform notes, motion and haptics (sections 6, 7)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.1 | 2026-10-31]

## Notification handling (FR-25, FR-26)

| Moment | Behaviour |
| ------ | --------- |
| Permission request | The system request shows once, right after the first successful sign-in on a phone, with no explanation card. Android 13 and later: runtime permission; Android 8.0 and later: one channel named `A_NOTIF_CHANNEL` (unverified). If denied: nothing more is shown, no hint, no setting in the app; every function works (AC-42). [v1.1 | 2026-10-31] |
| Text | Title `A_NOTIF_TITLE` ("Đơn mới"), body `A_NOTIF_BODY` ("{code}: {n} bánh, giao {date}"). No name, phone, address, note (AC-43). No reminders. |
| Tap, session valid | App opens S-A4 for the order: 1 tap with the phone on, 2 with the app closed (AC-31). Back returns to S-A3. |
| Tap, session ended | S-A1 shows, the order id is kept in memory only; after sign-in S-A4 opens (AC-43). |
| Tap, order not available | S-A4 shows `A_ORDER_GONE` (AC-21). |
| App in the foreground | In-app `Toast` `A_NOTIF_FOREGROUND` for 4 s; tapping it opens S-A4; S-A3 reloads and the tab number updates. Haptic: Selection / Context click. |
| Notification lost | The list is the truth: pull to refresh shows the order. |
| Sign out, sign out of other phones, switch-off | The device token is removed on sign out; the server stops sending (AC-44). |

## 6.1 Shared patterns

- Session ended (any 401): clear local order and customer data (BR-7), go to S-A1 with `A_SESSION_ENDED`.
- Right refused (403): `A_ERR_FORBIDDEN` as `Toast`, go to S-A3.
- Server validation refusal (400 class): `InlineMessage` with the field message; the form keeps values.
- Conflict: S-A4 behaviour. Settings have no stale-view rule (the last save wins, BR-11); a conflict-style refusal shows `A_ERR_GENERIC` and reloads (A-D2).
- Offline detection: reachability only chooses the text; a failed request triggers the state.
- Retry: `A_RETRY` repeats the failed request, shows Loading, never clears forms.
- Server date: the list answer carries the server date (Vietnam time) used for the due marks and for "today" and "tomorrow"; the device clock is never used for them (TQ-D8). [v1.1 | 2026-10-31]

## 6. Platform notes

| Topic | iOS | Android |
| ----- | --- | ------- |
| Material | iOS 26: Liquid Glass for tab bar, toolbar buttons, bottom bar, sheets (`TabView`, `glassEffect`, `GlassEffectContainer`); iOS 17 to 25: `material.fallback` | Android 12+: glass cards over blurred blobs; 8.0 to 11: opaque cards, flat blobs (design-system part 5) |
| Navigation | `NavigationStack`; swipe-back kept | Compose navigation; predictive back |
| Tab bar | Native `TabView`, two tabs (owner), Orders tab `.badge(n)` red; staff have no `TabView`, the number sits beside the title | `NavigationBar` with two destinations, `Badge` on the Orders icon; `HorizontalFloatingToolbar` is experimental and not used (TQ-D2) |
| Sheets | Native sheet, medium and large detents (S-A5, S-A10 edits, S-A12 add and detail, S-A13) | `ModalBottomSheet` |
| Dialogs and menus | `alert`; `Menu` for the date chip | Material `AlertDialog`; `DropdownMenu` |
| Pickers | `DatePicker` graphical (one date); hour and minute `DatePicker` | Material `DatePicker`, `TimePicker` (24 hour) |
| Photo | `PhotosPicker` (no permission) | Photo Picker (no permission) |
| Switch | `Toggle` | `Switch` |
| Code field | Content type one-time code | No autofill source for e-mail; paste supported |
| Keyboard | Number pad has no return key: `A_SIGNIN` stays above the keyboard | Same via IME insets |
| Call and Zalo | `tel:` URL; Zalo per ADR-0015 | Dial intent (no permission); Zalo per ADR-0015 |
| Notifications | Alert style (TQ-D3) | Channel `A_NOTIF_CHANNEL`, default importance (TQ-D3) |
| Pull to refresh | `refreshable` | Material pull-to-refresh |
| Fonts | Be Vietnam Pro (DS-Q3) | Roboto Flex (DS-Q3) |

## 7. Motion and haptics

Tokens and the base table are in design-system section 4. Admin additions:

| Event | Motion | iOS haptic | Android haptic |
| ----- | ------ | ---------- | -------------- |
| Confirm or complete succeeded | Badge cross-fade `motion.duration.short`, bar swaps with `motion.spring.standard`, due mark fades out, tab number counts down | Notification success | Confirm |
| Cancel succeeded | Sheet closes, reason card slides in `motion.duration.medium` | Notification success | Confirm |
| Status change refused (conflict) | Warning banner slides in | Notification error | Reject |
| Wrong or void code | Cells shake 4 pt once (skipped under `motion.reduced`) | Notification error | Reject |
| Filter chip chosen | Fill change `motion.duration.short` | Selection | Context click |
| Switch toggled | Native | Selection | Segment tick |
| New order in the foreground | Toast from top | Selection | Context click |
| Sign out of other phones done | Toast | Notification success | Confirm |
| Pull to refresh | Native | Native | Native |

Everything moves as a 150 ms cross-fade when Reduce Motion or remove-animations is on.
