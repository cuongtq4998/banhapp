# Admin Orders UI, part 6: S-A12 and S-A13, staff and account (section 5)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.1 | 2026-10-31] The design board has no screens for these. Form rules: [part 4](04-screens-settings.md). The devices screen, backup e-mail screen and recovery screen of v1.0 are removed (PRD deferred P-1, P-2).

### S-A12 Staff

- Purpose: add staff, see accounts, switch staff off or on (FR-5, BR-6). Entry: S-A6 row (owner only). [v1.1 | 2026-10-31]
- Layout: `TopBar` `A_ROW_STAFF` with `CountPill` `A_STAFF_COUNT`; `PrimaryButton` `A_ADD_STAFF`; `AccountRow` for the owner first (badge `A_ROLE_OWNER`, no chevron, cannot be changed), then staff by name with `StatusBadge` `A_ACCT_ACTIVE` or `A_ACCT_OFF`. The review account never appears.
- Add sheet (replaces the v1.0 screen): title `A_ADD_STAFF`; `TextField` name (`A_F_STAFF_NAME`, 1 to 100), `TextField` e-mail (`A_EMAIL_LABEL`); `NoticeText` `A_STAFF_ADD_HELP`; `PrimaryButton` `A_ADD_STAFF_SAVE`, disabled until both are filled. Validation: format `A_ERR_EMAIL_INVALID`; already used on an account in any letter case `A_ERR_EMAIL_TAKEN`; 31st active `A_ERR_STAFF_FULL` (AC-9). Success: `Toast` `A_STAFF_ADDED`, sheet closes, the list shows name and e-mail. [v1.1 | 2026-10-31]
- Row tap on a staff account opens a detail sheet: name, e-mail, role, status and one button: `A_DEACTIVATE` (Destructive `ConfirmDialog` `A_DEACTIVATE_TITLE` naming `{name}`, body `A_DEACTIVATE_BODY`: signed out on every phone, no notifications, history keeps the name, AC-10) or `A_REACTIVATE` (no dialog). Reactivating at 30 active: `A_ERR_STAFF_FULL`.
- Rules: at 30 active staff the add button is disabled with `NoticeText` `A_STAFF_FULL`.
- States: Default; Loading (skeleton rows); Empty (only the owner: owner row plus `NoticeText` `A_STAFF_NONE`); Error; Offline; Disabled (add at 30; sheet buttons while a request runs); Success (`Toast` `A_SAVED`, row updates).

### S-A13 Account (sheet, staff)

- Purpose: the staff member's own data and the two sign-out buttons (FR-2, FR-4, BR-1). Entry: account button on S-A3 (staff only). Owners use S-A6. [v1.1 | 2026-10-31]
- Layout: sheet title `A_ACCOUNT_TITLE`; `GlassCard` name, e-mail, role `A_ROLE_STAFF`; `SecondaryButton` `A_SIGNOUT_OTHERS` with the same `ConfirmDialog` as S-A6; `SecondaryButton` `A_SIGN_OUT` with the same `ConfirmDialog` as S-A6.
- States: Default; Loading N/A (data known from sign-in); Empty N/A; Error (`Toast` `A_ERR_GENERIC` for sign out of other phones, nothing changes); Offline (sign out still clears the local session, `A_OFFLINE_SIGNOUT`; the other button shows `A_OFFLINE_SAVE`); Disabled (buttons while one request runs); Success (`Toast` `A_SIGNOUT_OTHERS_DONE`).
