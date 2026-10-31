# Admin Orders UI, part 6: S-A16 to S-A20, staff, devices, account, backup e-mail (section 5)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31] The design board has no screens for these; they are new designs. Form rules: [part 4](04-screens-settings.md).

### S-A16 Staff

- Purpose: see accounts, deactivate or reactivate staff (FR-27, BR-8). Entry: S-A8 row (owner only).
- Layout: `TopBar` `A_ROW_STAFF` with `CountPill` `A_STAFF_COUNT` ("{n}/30 nhân viên đang hoạt động"); `PrimaryButton` `A_ADD_STAFF`; `AccountRow` for the owner first (badge `A_ROLE_OWNER`, no chevron, cannot be changed, AC-43), then staff by name with `StatusBadge` `A_ACCT_ACTIVE` or `A_ACCT_OFF`.
- Row tap on a staff account opens a detail sheet: name, e-mail, role, status, and one button: `A_DEACTIVATE` (Destructive `ConfirmDialog` `A_DEACTIVATE_TITLE` naming `{name}`, body `A_DEACTIVATE_BODY`: the person is signed out on every device and gets no notifications; history keeps the name, AC-14, AC-44) or `A_REACTIVATE` (no dialog). Reactivating when 30 are active: `A_ERR_STAFF_FULL`.
- Rules: at 30 active staff the add button is disabled with `NoticeText` `A_STAFF_FULL` (AC-43).
- States: Default; Loading (skeleton rows); Empty (only the owner exists: owner row plus `NoticeText` `A_STAFF_NONE`); Error; Offline; Disabled (add at 30; sheet buttons while a request runs); Success (`Toast` `A_SAVED`, row updates).

### S-A17 Add staff

- Purpose: FR-27. Layout: `TopBar` `A_ADD_STAFF`; `TextField` name (`A_F_STAFF_NAME`, 1 to 100), `TextField` e-mail (`A_EMAIL_LABEL`); `NoticeText` `A_STAFF_ADD_HELP` ("Người này đăng nhập bằng mã gửi về email này."); `BottomActionBar` `A_ADD_STAFF_SAVE`.
- Validation: format `A_ERR_EMAIL_INVALID`; already on an account (any letter case) or equal to the owner's backup e-mail `A_ERR_EMAIL_TAKEN`; 31st active `A_ERR_STAFF_FULL` (AC-43). Success: `Toast` `A_STAFF_ADDED`, back to S-A16 (AC-42).
- States: Default (Save disabled until both fields are filled); Loading; Empty N/A; Error; Offline; Disabled; Success.

### S-A18 Devices

- Purpose: see signed-in devices and revoke (FR-37, FR-43). Entry: S-A8 row (owner: all accounts), S-A19 (staff: own only), and after recovery sign-in (S-A3).
- Layout: `TopBar` `A_DEVICES_TITLE`; after recovery a `BannerAction` `A_RECOVERY_DONE` (Info, dismissible with `A_DISMISS`, says that notices were sent to both e-mails and to revoke the old device); owner view grouped by account with the account name as a section label (`type.section`); each `DeviceRow`: device name, last used ("Dùng lần cuối: {date} {time}"), the current device shows pill `A_DEVICE_THIS` and no revoke button (the person uses Sign out for it), others show `SecondaryButton` `A_REVOKE`.
- Revoke: `ConfirmDialog` (Destructive) `A_REVOKE_TITLE` naming `{device}` and `{account}`, body `A_REVOKE_BODY` ("Máy này sẽ bị đăng xuất, trong tối đa 5 phút."), buttons `A_REVOKE`, `A_BACK` (AC-55). On success the row shows `A_REVOKED` then disappears with a `motion.duration.medium` fade; `Toast` `A_REVOKED`. A staff member sees `NoticeText` `A_DEVICES_OWN_ONLY` (AC-56).
- States: Default; Loading (skeleton); Empty N/A (the current device always exists); Error; Offline; Disabled (revoke while one runs); Success.

### S-A19 Account (staff)

- Purpose: the staff member's own data, devices, sign out (FR-4, FR-37, BR-1). Entry: account button on S-A4 (staff only). Owners use S-A8.
- Layout: `TopBar` `A_ACCOUNT_TITLE`; `GlassCard` name, e-mail, role `A_ROLE_STAFF`; `SettingsRow` `A_ROW_DEVICES` (to S-A18); `SecondaryButton` `A_SIGN_OUT` with the same `ConfirmDialog` as S-A8.
- States: Default; Loading N/A (data known from sign-in); Empty N/A; Error N/A (local data); Offline (sign out still clears the local session, `A_OFFLINE_SIGNOUT`); Disabled N/A; Success N/A.

### S-A20 Backup e-mail (owner)

- Purpose: register or change the backup e-mail with a code to the new address (FR-42, BR-17, AC-57). Entry: S-A8 row or `A_SET_NOW` banner.
- Layout: `TopBar` `A_BACKUP_TITLE`; `NoticeText` `A_BACKUP_INTRO` (why: recovery if the phone is lost); current value row (masked, for example "c***@example.com", or `A_BACKUP_NONE`); step 1: `TextField` new e-mail (`A_F_BACKUP`), `PrimaryButton` `A_SEND_CODE`; step 2 on the same screen: `OtpField` (`A_BACKUP_CODE_PROMPT` with `{email}`), resend line as S-A2, `PrimaryButton` `A_CONFIRM_BACKUP`.
- Validation: format `A_ERR_EMAIL_INVALID`; equal to the owner's sign-in address or a staff address `A_ERR_BACKUP_TAKEN`; wrong or expired code as S-A2. The backup e-mail is saved only after the code is accepted. Success: `Toast` `A_BACKUP_SAVED`, back to S-A8, the attention dot and reminder disappear.
- States: Default; Loading; Empty (none registered: `A_BACKUP_NONE`); Error; Offline; Disabled (buttons until valid input); Success.
