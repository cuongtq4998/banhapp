# Admin Orders UI, part 4: S-A6, S-A9 to S-A11, settings (section 5)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.1 | 2026-10-31]

Form rules for all settings screens (S-A8 to S-A12): every field is required (BR-11); the save button is disabled until at least one value differs from the stored one; tapping Save validates all fields, shows every error at once with a message that names the field (`A_ERR_*` with `{field}`) and moves focus to the first invalid field (AC-40); the server answer wins and the same messages come back from it; nothing is stored when any field fails. Numbers use the number pad and show thousand separators when the field loses focus. A saved change applies to new orders only (AC-41); `A_NEW_ORDERS_ONLY` shows once as a note under the entries on S-A6. Form states are written once: Loading = skeleton card until values arrive; Error = `StateView` with retry; Offline = `StateView` offline (save attempts: `A_OFFLINE_SAVE`); Success = `Toast` `A_SAVED` and return to the parent. [v1.1 | 2026-10-31]

### S-A6 Settings (owner)

- Purpose: one area with five entries (FR-20, AC-48); sign out. Entry: tab 2. Staff never see this tab or screen (AC-8). [v1.1 | 2026-10-31]
- Layout: large title `A_SETTINGS_TITLE`; one `GlassCard` with exactly five `SettingsRow`s in this order: `A_ROW_CAKES` (value "{n}/12"), `A_ROW_RULES` (value `A_ROW_RULES_VALUE`), `A_ROW_DELIVERY_SET` (value: "{districts} quận/huyện, {slots} khung giờ" active counts, key `A_ROW_DELIVERY_VALUE`), `A_ROW_SHOP` (value: shop name), `A_ROW_STAFF` (value "{n}/30"); no groups, no second menu level. Below: `NoticeText` `A_NEW_ORDERS_ONLY`; `SecondaryButton` `A_SIGNOUT_OTHERS` with `ConfirmDialog` (`A_SIGNOUT_OTHERS_TITLE`, `A_SIGNOUT_OTHERS_BODY`, buttons `A_SIGNOUT_OTHERS` and `A_BACK`); `SecondaryButton` `A_SIGN_OUT` (text `color.destructive`) with `ConfirmDialog` (`A_SIGNOUT_TITLE`, `A_SIGNOUT_BODY`, buttons `A_SIGN_OUT`, `A_BACK`). [v1.1 | 2026-10-31]
- Actions: open an area; sign out (AC-6: session ends on the server, local customer data removed, notifications stop, S-A1 shows); sign out all other phones (FR-4, AC-7: the dialog confirms, then `Toast` `A_SIGNOUT_OTHERS_DONE`; this phone stays signed in; the other phones show S-A1 when they next try, within 5 minutes). [v1.1 | 2026-10-31]
- States: Default; Loading (row values show a placeholder, rows tappable); Empty N/A; Error (values show a dash; the sign-out buttons stay usable; for "sign out all other phones" a failure shows `A_ERR_GENERIC` as `Toast` and nothing changes); Offline (same plus `A_OFFLINE_SIGNOUT` after sign out, the local session is cleared anyway; "sign out all other phones" shows `A_OFFLINE_SAVE`); Disabled (both buttons while one request runs); Success (as Actions).

### S-A9 Ordering

- Purpose: daily limit, days of notice, minimum cakes (FR-22, BR-11). Layout: `TopBar` `A_ROW_RULES`; one `GlassCard` with three `TextField` rows, each with a helper line: `A_F_LIMIT` (1 to 9 999), `A_F_LEAD` (0 to 14), `A_F_MIN` (1 to 20 and not above the daily limit, checked on the pair, AC-36); read-only row `A_HORIZON_FIXED`; `NoticeText` `A_RULES_EFFECT`; `BottomActionBar` `A_SAVE`.
- Daily-limit warning (AC-35): when the new limit is lower than the cakes accepted for some dates, Save first asks the server which dates are affected; if any, `ConfirmDialog` (Neutral) `A_LIMIT_WARN_TITLE`, body `A_LIMIT_WARN_BODY` with `{count}` and a list of `{date} ({cakes} bánh)` (scrolls when long), buttons `A_SAVE_ANYWAY` and `A_BACK`. Saving cancels nothing; the body says so.
- Validation: `A_ERR_RANGE_INT` with `{field}`, `{min}`, `{max}`; minimum above limit `A_ERR_MIN_ABOVE_LIMIT`.
- States: as the form rules; Disabled also for Save while the affected-date request runs (spinner).

### S-A10 Delivery

- Purpose: districts with fees and time slots on one screen (FR-23). Layout: `TopBar` `A_ROW_DELIVERY_SET`; two sections in the order: section label `A_SEC_DISTRICTS` with a trailing glass add button (label `A_ADD_DISTRICT`) and rows; section label `A_SEC_SLOTS` with add button (`A_ADD_SLOT`) and rows. A district row: name, fee (`type.body.strong`), `ToggleRow` `A_ACTIVE`. A slot row: "{start} – {end}" (`type.list.name`), `ToggleRow` `A_ACTIVE`. Row tap opens an edit sheet. [v1.1 | 2026-10-31]
- District sheet: title (add or change), `TextField` name (`A_F_DISTRICT`, 1 to 100), `TextField` fee in dong (`A_F_FEE`, 1 to 10 000 000, number pad), note `A_FEE_EFFECT`, `PrimaryButton` `A_SAVE`. Rules: name unique `A_ERR_DISTRICT_DUP`; fee outside range `A_ERR_RANGE_INT` (0 refused, no free delivery); the last active district cannot be switched off (`A_ERR_LAST_DISTRICT`, AC-37).
- Slot sheet: title `A_SLOT_ADD_TITLE`/`A_SLOT_EDIT_TITLE`; two native time pickers `A_F_START`, `A_F_END` (24 hour); `A_SAVE`. Rules: start before end `A_ERR_SLOT_ORDER`; duplicate `A_ERR_SLOT_DUP`; the last active slot cannot be switched off (`A_ERR_LAST_SLOT`, AC-38).
- A switch change saves at once (pending: switch dimmed, then settled; on refusal it returns to on with a `Toast` of the rule; on failure with `A_ERR_GENERIC`).
- States: Default; Loading (skeleton rows in both sections); Empty (per section: `A_DISTRICTS_EMPTY` or `A_SLOTS_EMPTY` with the add button; cannot happen after launch); Error; Offline; Disabled (switches while one change runs); Success (`Toast` `A_SAVED`, sheet closes, rows update).

### S-A11 Shop info

- Purpose: FR-24. Layout: `TopBar` `A_ROW_SHOP`; `GlassCard` with `TextField` name (`A_F_SHOP_NAME`, 1 to 100), multiline greeting (`A_F_GREETING`, 1 to 300, counter `{n}/300`), contact phone (`A_F_PHONE`, phone keyboard), Zalo (`A_F_ZALO`, a Vietnamese number or an account name of 3 to 100 characters, BR-11); `BottomActionBar` `A_SAVE`.
- Validation: empty `A_ERR_REQUIRED`; too long `A_ERR_TOO_LONG` with `{max}`; invalid phone `A_ERR_PHONE` (AC-39, AC-40).
- States: Default; Loading; Empty N/A; Error; Offline; Disabled (Save while unchanged or running); Success.
