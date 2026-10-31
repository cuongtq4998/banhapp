# Admin Orders UI, part 2: Common layout, S-A1 and S-A2 (section 5)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.1 | 2026-10-31]

## 5. Screen specs

### Common layout

Every screen sits on `AppBackground`. Screens inside the app use `TopBar` (round glass back button, `type.title.large` title below); tab roots (S-A3, S-A6) have the large title and no back button. Form screens put the save action in a `BottomActionBar` (one `PrimaryButton`). Content scrolls; the bar never covers content. Standard state meanings used below:

- Loading: `StateView` skeleton for lists and detail; a spinner inside the pressed button for actions (same width, other controls disabled).
- Empty: `StateView` with icon, text, and when useful one action.
- Error: `StateView` with `A_ERR_GENERIC` and `A_RETRY`; on a form, an `InlineMessage` (Error) above the bar and the form keeps its values.
- Offline: `StateView` with `A_OFFLINE` and `A_RETRY`; on a form, the save button stays enabled and the attempt shows `A_OFFLINE_SAVE`; nothing is saved.
- Disabled: control dimmed (`color.disabledFill`), still readable by a screen reader with its state.
- Success: for a save, the screen closes (or stays) with a `Toast` `A_SAVED`; for a status change, the detail updates in place.
- Dirty back: leaving a form with unsaved changes shows `ConfirmDialog` (`A_DISCARD_TITLE`, `A_DISCARD_BODY`, buttons `A_DISCARD`, `A_KEEP_EDITING`).

### S-A1 Sign in: e-mail

- Purpose: request a one-time code (FR-1). Entry: app start without a valid session; session ended; sign out; notification tap with ended session. Exit: S-A2, then S-A3 or S-A4 after sign-in. The owner uses the same screen and the same single code (AC-2); there is no recovery link. [v1.1 | 2026-10-31]
- Layout: `LogoMark` (admin size, `size.logo`), title `A_SIGNIN_TITLE` (`type.display`), `NoticeText` `A_SIGNIN_HINT`, `TextField` e-mail (label `A_EMAIL_LABEL`, keyboard e-mail, no auto-capitalisation, no auto-correct, content type e-mail, trimmed), `PrimaryButton` `A_SEND_CODE`, `NoticeText` `A_SESSION_NOTE`.
- Data shown: none from the server. Same screen and same next step whether or not the address is registered (FR-1, AC-1); no text such as "address not found".
- Actions: send code. The keyboard "Send" key submits when valid.
- Validation: empty or not an e-mail format shows `A_ERR_EMAIL_INVALID` under the field after the first send attempt; format only (BR-4).
- Banner: `A_SESSION_ENDED` (`InlineMessage`, Info) shows above the field when the person arrives because the session ended (AC-5, AC-10); the app does not say why, because the server does not.
- States: Default (button disabled until the field is not empty); Loading (button spinner, field disabled); Empty N/A; Error (`A_ERR_RATE_SEND` with `{minutes}` when 3 codes per hour are used, AC-4; `A_ERR_GENERIC`; field kept); Offline (`A_OFFLINE_SAVE`); Disabled (button when empty); Success (move to S-A2).

### S-A2 Sign in: code

- Purpose: enter the 6-digit code (FR-1, FR-2). Entry: S-A1 after send. Exit: S-A3 (or S-A4 when a notification started the sign-in); S-A1 by "change e-mail".
- Layout: `TopBar` back (to S-A1), title `A_CODE_TITLE`, text `A_CODE_PROMPT` with `{email}` (bold), `OtpField`, resend line (`A_RESEND_WAIT` with `{seconds}` while counting; text button `A_RESEND` when enabled), text button `A_CHANGE_EMAIL` (S-A1 with the address kept, AC-3), `PrimaryButton` `A_SIGNIN`.
- Behaviour: the field takes focus on open; number pad; content type one-time code; paste of 6 digits fills all cells; the button enables at 6 digits; the sixth digit does not auto-submit. Resend is disabled for 30 s after each code (AC-3); the countdown is announced every 10 s.
- Errors (cells cleared, refocused, one shake): `A_CODE_WRONG` (wrong, or already used); `A_CODE_EXPIRED` ("code no longer valid, request a new one") for an expired code and for a code voided by 5 wrong entries, the same text (AC-2, AC-4; there is no lock and no wait, so the person simply taps resend); `A_ERR_RATE_SEND` with `{minutes}` on resend when 3 codes in the hour are used (AC-4). [v1.1 | 2026-10-31]
- States: Default; Loading (button spinner, cells disabled); Empty N/A; Error as above; Offline `A_OFFLINE_SAVE`; Disabled (button below 6 digits; resend during the wait); Success (`Notification success` haptic, move on).
- After sign-in: the owner and staff land on the list and the system notification permission request shows once, directly, with no explanation card (`A_NOTIF_*` priming removed to save a step; if denied nothing else shows, FR-25, AC-42). [v1.1 | 2026-10-31]
