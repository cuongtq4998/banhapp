# Admin Orders UI, part 2: Common layout, S-A1 to S-A3 (section 5)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31]

## 5. Screen specs

### Common layout

Every screen sits on `AppBackground`. Screens inside the app use `TopBar` (round glass back button, `type.title.large` title below); tab roots (S-A4, S-A8) have the large title and no back button. Form screens put the save action in a `BottomActionBar` (one `PrimaryButton`). Content scrolls; the bar never covers content. Standard state meanings used below:

- Loading: `StateView` skeleton for lists and detail; a spinner inside the pressed button for actions (the button stays the same width, other controls disabled).
- Empty: `StateView` with icon, text, and when useful one action.
- Error: `StateView` with `A_ERR_GENERIC` and `A_RETRY`; on a form, an `InlineMessage` (Error) above the bar and the form keeps its values.
- Offline: `StateView` with `A_OFFLINE` and `A_RETRY`; on a form, the save button stays enabled and the attempt shows `A_OFFLINE_SAVE`; nothing is saved.
- Disabled: control dimmed (`color.disabledFill`), still readable by a screen reader with its state.
- Success: for a save, the screen closes (or stays) with a `Toast` `A_SAVED`; for a status change, the detail updates in place.
- Dirty back: leaving a form with unsaved changes shows `ConfirmDialog` (`A_DISCARD_TITLE`, `A_DISCARD_BODY`, buttons `A_DISCARD`, `A_KEEP_EDITING`).

### S-A1 Sign in: e-mail

- Purpose: request a one-time code (FR-1). Entry: app start without a valid session; session ended; sign out; notification tap with ended session. Exit: S-A2 (code requested), S-A3 (link), S-A4 or S-A6 after sign-in.
- Layout: `LogoMark` (admin size, `size.logo`), title `A_SIGNIN_TITLE` (`type.display`), `NoticeText` `A_SIGNIN_HINT`, `TextField` e-mail (label `A_EMAIL_LABEL`, keyboard e-mail, no auto-capitalisation, no auto-correct, content type e-mail, trimmed), `PrimaryButton` `A_SEND_CODE`, text link `A_LOST_PHONE` (leads to S-A3), `NoticeText` `A_SESSION_NOTE` ("signed in 7 days, renewed on each use").
- Data shown: none from the server. Same screen and same next step whether or not the address is registered (FR-1, AC-2); no text such as "address not found".
- Actions: send code (FR-1); open recovery (FR-43). Keyboard "Send" key submits when valid.
- Validation: empty or not an e-mail format shows `A_ERR_EMAIL_INVALID` under the field after the first send attempt; the check is format only.
- Banner: `A_SESSION_ENDED` (Info) shows above the field when the person arrives because the session ended (AC-14, AC-54); the app does not tell why (revoked, deactivated, expired), because the server does not.
- States: Default (button disabled until the field is not empty); Loading (button spinner, field disabled); Empty N/A (no data); Error (`A_ERR_RATE_SEND` with `{minutes}` when 3 codes per hour are used, AC-9; `A_ERR_GENERIC` for server errors; field kept); Offline (`A_OFFLINE_SAVE`); Disabled (button when the field is empty); Success (move to S-A2).

### S-A2 Sign in: code

- Purpose: enter the 6-digit code (FR-2, FR-3). Entry: S-A1 after send. Exit: S-A4 (or S-A6 when a notification started the sign-in), back to S-A1 by "change e-mail".
- Layout: `TopBar` back (to S-A1), title `A_CODE_TITLE`, text `A_CODE_PROMPT` with the e-mail `{email}` (bold), `OtpField`, resend line (`A_RESEND_WAIT` with `{seconds}` while counting; text button `A_RESEND` when enabled), text button `A_CHANGE_EMAIL` (FR-3, AC-7: S-A1 shows with the address kept), `PrimaryButton` `A_SIGNIN`.
- Behaviour: the field takes focus on open; number pad; content type one-time code; paste of 6 digits fills all cells; the button enables at 6 digits; entering the sixth digit does not auto-submit. Resend is disabled for 30 s after each code (BR-5, AC-6); the countdown is announced every 10 s, not every second.
- Validation and errors (all keep the cells, clear them and refocus, field shakes once): `A_CODE_WRONG` (wrong, or used), `A_CODE_EXPIRED` (older than 10 minutes, AC-4), `A_CODE_LOCKED` with `{minutes}` (5 wrong codes, AC-8; field and button disabled, the person can go back), `A_ERR_RATE_SEND` on resend (AC-9).
- States: Default; Loading (button spinner, cells disabled); Empty N/A; Error as above; Offline `A_OFFLINE_SAVE`; Disabled (button below 6 digits; resend during wait; all while locked); Success (`Notification success` haptic, move on).
- After sign-in: owner and staff land on S-A4 and the notification permission flow of part 7 runs once.

### S-A3 Recovery sign-in (owner)

- Purpose: the owner signs in on a new device with two codes (FR-43, BR-17). Entry: link on S-A1. Exit: S-A18 with the recovery notice banner, then S-A4.
- Layout: `TopBar` back, title `A_RECOVERY_TITLE`, `NoticeText` `A_RECOVERY_INTRO` (says that it works only when a backup e-mail is registered, and that two codes are sent), step 1: `TextField` owner e-mail, `PrimaryButton` `A_SEND_TWO_CODES`; step 2 (same screen, fields appear below): `OtpField` labelled `A_RECOVERY_CODE_OWNER` and `OtpField` labelled `A_RECOVERY_CODE_BACKUP`, resend line as S-A2, `PrimaryButton` `A_SIGNIN_RECOVERY`.
- Behaviour: the step 2 cells always appear after step 1 whether or not a backup e-mail exists (no leak, see Q-D1). The button enables only when both fields have 6 digits. A failure never says which code was wrong (`A_RECOVERY_FAILED`, AC-59). Lock and rate-limit messages as S-A2.
- Validation: e-mail format as S-A1.
- States: Default; Loading; Empty N/A; Error (`A_RECOVERY_FAILED`, `A_CODE_LOCKED`, `A_ERR_RATE_SEND`, `A_ERR_GENERIC`; both fields cleared, e-mail kept); Offline; Disabled (button until both codes complete; resend during wait); Success (haptic success, S-A18 with the `A_RECOVERY_DONE` banner).
