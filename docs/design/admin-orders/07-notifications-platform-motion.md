# Admin Orders UI, part 7: Notifications, shared patterns, platform notes, motion and haptics (sections 6, 7)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31]

## Notification handling (FR-31 to FR-35)

| Moment | Behaviour |
| ------ | --------- |
| Permission request | After the first successful sign-in on a device, S-A4 shows a short explanation card `A_NOTIF_PRIME` with `PrimaryButton` `A_NOTIF_ALLOW` (starts the system request) and text button `A_NOTIF_LATER`. The system request is never shown without it. Choosing later asks again at the next sign-in. Android 13 and later: runtime permission; Android 8.0 and later: one channel named `A_NOTIF_CHANNEL` (unverified, see research). |
| Denied | All functions work (AC-51). `BannerAction` `A_NOTIF_HINT` with `A_OPEN_SETTINGS` shows once per sign-in on S-A4 (S-A4 spec). |
| Text | Title `A_NOTIF_TITLE` ("Đơn mới"), body `A_NOTIF_BODY` ("{code}: {n} bánh, giao {date}"). No name, phone, address, note (FR-32, AC-49). No reminders, no badge number for the customer data. |
| Tap, session valid | App opens S-A6 for the order in at most 2 taps total (notification, then the order) (G-1, AC-50). The back button returns to S-A4, not to the app exit. |
| Tap, session ended | S-A1 shows with the pending order kept in memory only (the order id, no customer data); after sign-in S-A6 opens (AC-50). |
| Tap, order not available | S-A6 shows `A_ORDER_GONE` (outside 90 days or removed access) (FR-41). |
| App in the foreground | No system banner is relied on; an in-app `Toast` `A_NOTIF_FOREGROUND` ("Có đơn mới {code}") appears for 4 s, tapping it opens S-A6, and S-A4 refreshes if visible. Haptic: Selection / Context click. |
| Notification lost | The list is the source of truth: pull to refresh shows the order (BR-14, AC-48). |
| Sign out, revoke, deactivation | The device token is removed on sign out; the server stops sending (FR-35). |

## 6.1 Shared patterns

- Session ended (any 401): clear local order and customer data (BR-15), go to S-A1 with `A_SESSION_ENDED`.
- Right refused (403): `A_ERR_FORBIDDEN` as `Toast`, go to S-A4.
- Server validation refusal (400 class): `InlineMessage` with the field message; the form keeps values.
- Conflict: S-A6 behaviour. Settings have no stale-view conflict rule in the PRD; a conflict-style refusal shows `A_ERR_GENERIC` and reloads (assumption A-D2).
- Offline detection: the system reachability state is used only to choose the text; a failed request is what triggers the state.
- Retry: `A_RETRY` repeats the failed request, shows Loading, never clears forms.
- Time shown "last updated" and "last used" is local clock formatted in Vietnam time.

## 6. Platform notes

| Topic | iOS | Android |
| ----- | --- | ------- |
| Material | iOS 26: Liquid Glass for tab bar, toolbar buttons, bottom bar, sheets (SwiftUI `TabView`, `glassEffect`, `GlassEffectContainer`); iOS 17 to 25: `material.fallback` | Android 12+: glass cards over blurred blobs; Android 8.0 to 11: opaque cards, flat blobs (design-system part 5) |
| Navigation | `NavigationStack`; swipe-back kept; custom header per `TopBar` | Compose navigation; predictive back; custom header |
| Tab bar | Native `TabView`, two tabs (owner); hidden for staff by showing no `TabView` | `NavigationBar` with two destinations (owner); `HorizontalFloatingToolbar` is experimental and not used (TQ-D2) |
| Sheets | Native sheet with medium and large detents (S-A5, S-A7, S-A11 and S-A12 edit, S-A16 detail) | `ModalBottomSheet` |
| Dialogs | `alert` / `confirmationDialog` | Material `AlertDialog` |
| Pickers | `DatePicker` (graphical for one date, compact for range), `DatePicker` hour and minute | Material `DatePicker`, `TimePicker` (24 hour) |
| Photo | `PhotosPicker` (no permission) | Photo Picker (no permission) |
| Switch | `Toggle` | `Switch` |
| Code field | Content type one-time code | No autofill source for e-mail; paste supported |
| Keyboard | Number pad has no return key: `A_SIGNIN` button stays above the keyboard (bar moves up with the keyboard) | Same via IME insets |
| Call and Zalo | `tel:` URL; Zalo per ADR-0015 | Dial intent (no permission); Zalo per ADR-0015 |
| Notifications | Alert style, no sound choice made here (TQ-D3) | Channel `A_NOTIF_CHANNEL`, default importance (TQ-D3) |
| Pull to refresh | `refreshable` | Material pull-to-refresh |
| Fonts | Be Vietnam Pro (DS-Q3) | Roboto Flex (DS-Q3) |

## 7. Motion and haptics

Tokens and the base table are in design-system section 4. Admin additions:

| Event | Motion | iOS haptic | Android haptic |
| ----- | ------ | ---------- | -------------- |
| Confirm or complete succeeded | Badge cross-fade `motion.duration.short`, bar swaps with `motion.spring.standard` | Notification success | Confirm |
| Cancel succeeded | Sheet closes, reason card slides in `motion.duration.medium` | Notification success | Confirm |
| Status change refused (conflict) | Warning banner slides in | Notification error | Reject |
| Wrong code | Cells shake 4 pt once (skipped under `motion.reduced`) | Notification error | Reject |
| Filter chip toggled | Fill change `motion.duration.short` | Selection | Context click |
| Switch toggled | Native | Selection | Segment tick |
| New order in the foreground | Toast from top | Selection | Context click |
| Device revoked | Row fades out `motion.duration.medium` | Notification success | Confirm |
| Pull to refresh | Native | Native | Native |

Everything moves as a 150 ms cross-fade when Reduce Motion or remove-animations is on.
