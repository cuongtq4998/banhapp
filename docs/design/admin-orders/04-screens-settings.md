# Admin Orders UI, part 4: S-A8 to S-A12, settings (section 5)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31]

Form rules for all settings screens (S-A9 to S-A15, S-A17, S-A20): every field is required (BR-9); the save button is disabled until at least one value differs from the stored one; tapping Save validates all fields, shows every error at once with a message that names the field (`A_ERR_*` keys with `{field}`) and moves focus to the first invalid field (FR-28, AC-45); the server answer wins and the same messages come back from it; nothing is stored when any field fails. Numbers use the number pad and show thousand separators when the field loses focus. A saved change applies to new orders only (FR-29); the settings home shows `A_NEW_ORDERS_ONLY` once as a note. Form states in the lists below are written once and not repeated: Loading = skeleton card until values arrive; Error = `StateView` with retry; Offline = `StateView` offline (save attempts: `A_OFFLINE_SAVE`); Success = `Toast` `A_SAVED` and return to the parent.

### S-A8 Settings (owner)

- Purpose: entry to owner areas (FR-21, FR-42). Entry: tab 2. Staff never see this tab or screen (AC-32).
- Layout: large title `A_SETTINGS_TITLE`; `BannerAction` `A_BACKUP_REMINDER` with button `A_SET_NOW` while no backup e-mail is registered (BR-17); `GlassCard` group "Cửa hàng": `SettingsRow` `A_ROW_SHOP` (value: shop name), `A_ROW_RULES` (value: "Giới hạn {limit} bánh/ngày"), `A_ROW_SLOTS` (value: active count), `A_ROW_DISTRICTS` (value: active count), `A_ROW_CAKES` (value: "{n}/12"); group "Tài khoản": `A_ROW_STAFF` (value "{n}/30"), `A_ROW_DEVICES`, `A_ROW_BACKUP` (value: masked or "Chưa đăng ký", attention dot when none); `SecondaryButton` `A_SIGN_OUT` (text `color.destructive`) with a `ConfirmDialog` (`A_SIGNOUT_TITLE`, `A_SIGNOUT_BODY`, buttons `A_SIGN_OUT`, `A_BACK`); `NoticeText` `A_NEW_ORDERS_ONLY`.
- Actions: open each area; sign out (FR-4, AC-11): the session ends on the server, local customer data is removed, notifications stop, S-A1 shows.
- States: Default; Loading (row values show a placeholder, rows are tappable); Empty N/A; Error (values show a dash, rows remain usable; no blocking error); Offline (same as Error plus `Toast` on sign out: `A_OFFLINE_SIGNOUT`, the app still clears the local session); Disabled N/A; Success N/A.

### S-A9 Shop information

- Purpose: FR-26. Layout: `TopBar` `A_ROW_SHOP`; `GlassCard` with `TextField` name (`A_F_SHOP_NAME`, 1 to 100), multiline `TextField` greeting (`A_F_GREETING`, 1 to 300, counter `{n}/300`), `TextField` contact phone (`A_F_PHONE`, phone keyboard), `TextField` Zalo (`A_F_ZALO`, phone keyboard, same format as the customer app uses); `BottomActionBar` `A_SAVE`.
- Validation: empty `A_ERR_REQUIRED`; too long `A_ERR_TOO_LONG` with `{max}`; invalid phone `A_ERR_PHONE` (AC-41, AC-45).
- States: Default; Loading; Empty N/A (values always exist); Error; Offline; Disabled (Save while unchanged or running); Success.

### S-A10 Ordering rules

- Purpose: daily limit, lead days, minimum cakes (FR-24, FR-40, BR-9, BR-10, BR-21). Layout: `TopBar` `A_ROW_RULES`; one `GlassCard` with three `TextField` rows, each with a helper line: `A_F_LIMIT` ("Số bánh tối đa mỗi ngày", 1 to 9 999), `A_F_LEAD` ("Đặt trước tối thiểu (ngày)", 0 to 14), `A_F_MIN` ("Số bánh tối thiểu mỗi đơn", 1 to 20 and not above the daily limit); read-only row `A_HORIZON_FIXED` ("Đặt trước tối đa 30 ngày. Không thay đổi được."); `NoticeText` `A_RULES_EFFECT`; `BottomActionBar` `A_SAVE`.
- Daily-limit warning (BR-10, AC-38): when the new limit is lower than the cakes accepted for some dates, Save first asks the server which dates are affected; if there are any, `ConfirmDialog` (Neutral) `A_LIMIT_WARN_TITLE`, body `A_LIMIT_WARN_BODY` with `{count}` and a list of `{date} ({cakes} bánh)` (scrolls when long), buttons `A_SAVE_ANYWAY` and `A_BACK`. Saving cancels nothing; the body says so.
- Validation: `A_ERR_RANGE_INT` with `{field}`, `{min}`, `{max}`; minimum above limit `A_ERR_MIN_ABOVE_LIMIT` (AC-66).
- States: as the form rules; Disabled also for Save while the affected-date request runs (spinner).

### S-A11 Time slots

- Purpose: FR-25. Layout: `TopBar` `A_ROW_SLOTS` with a trailing glass add button (label `A_ADD_SLOT`); list of `GlassCard` rows: "{start} – {end}" (`type.list.name`) with `ToggleRow` (`A_ACTIVE`); row tap opens the edit sheet.
- Edit sheet (add and change): title `A_SLOT_EDIT_TITLE`/`A_SLOT_ADD_TITLE`; two native time pickers `A_F_START`, `A_F_END` (24 hour); `PrimaryButton` `A_SAVE`; sheet states as the form rules.
- Rules: start before end `A_ERR_SLOT_ORDER`; an identical start and end `A_ERR_SLOT_DUP` (AC-40); turning off the last active slot is refused: the switch returns to on and `Toast` `A_ERR_LAST_SLOT` shows (BR-11). A switch change saves at once (pending state: switch dimmed, then settled; failure returns it with `A_ERR_GENERIC`).
- States: Default; Loading (3 skeleton rows); Empty (cannot happen after launch; if the list is empty `StateView` `A_SLOTS_EMPTY` with `A_ADD_SLOT`); Error; Offline; Disabled (switches while one change runs); Success (`Toast` `A_SAVED`).

### S-A12 Districts and fees

- Purpose: FR-23. Layout and behaviour as S-A11: add button `A_ADD_DISTRICT`; row shows name and fee "{fee}" (`type.body.strong`) and the switch; edit sheet with `TextField` name (`A_F_DISTRICT`, 1 to 100) and `TextField` fee in dong (`A_F_FEE`, whole number 1 to 10 000 000, number pad); `A_SAVE`.
- Rules: name unique `A_ERR_DISTRICT_DUP`; fee outside range `A_ERR_RANGE_INT` (0 is refused, no free delivery); last active district cannot be turned off, `A_ERR_LAST_DISTRICT` (AC-36). A note in the sheet `A_FEE_EFFECT`: a fee change applies to new orders only (AC-35, AC-46).
- States: as S-A11 (Empty text `A_DISTRICTS_EMPTY`).
