# Admin Orders UI, part 5: S-A13 to S-A15, cakes (section 5)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31] Form rules and the shared state meanings are in [part 4](04-screens-settings.md) and [part 2](02-screens-sign-in.md). The design board has no cake management screens; these are new designs built from the board's `ProductCard` list and form styles.

### S-A13 Cakes

- Purpose: see all cakes not removed and start add, edit (FR-22, FR-38, FR-39). Entry: S-A8 row. Exit: S-A14 (row), S-A15 (add).
- Layout: `TopBar` `A_ROW_CAKES` with the `CountPill` `A_CAKES_COUNT` ("{n}/12 bánh"); `PrimaryButton` `A_ADD_CAKE` (full width under the title, with a plus icon); list of cake rows built like `ProductCard`: `size.thumb` image, name, price (`type.body.strong`), `StatusBadge` `A_CAKE_ACTIVE` ("Đang bán") or `A_CAKE_HIDDEN` ("Đã ẩn"); hidden rows are dimmed to 70% but stay readable. Removed cakes are never listed (AC-63).
- Rules: when 12 cakes exist the add button is disabled and `NoticeText` `A_CAKES_FULL` explains why (FR-38, AC-61); the server also refuses a 13th (`A_ERR_CAKES_FULL`). Order: active first, then hidden, each by name.
- Data: picture, name, price, active or hidden. The description is shown on S-A14 only.
- States: Default; Loading (4 skeleton rows); Empty (cannot normally happen because one active cake must remain; if the list is empty `StateView` `A_CAKES_EMPTY` with `A_ADD_CAKE`); Error; Offline; Disabled (add button at 12); Success N/A. Image failed: `color.image.placeholder` with the icon and `A_IMG_FAILED_A11Y` label.

### S-A14 Edit cake

- Purpose: change name, description, price, active or hidden; remove (FR-22, FR-39, BR-11, BR-19). Entry: row on S-A13.
- Layout: `TopBar` (cake name); read-only picture card (`size.imagePreview`, `radius.image`) with `NoticeText` `A_IMG_NOT_EDITABLE` ("Ảnh không đổi được. Muốn đổi ảnh, hãy thêm bánh mới rồi xóa bánh này."); `GlassCard` with `TextField` name (`A_F_CAKE_NAME`, 1 to 100), multiline description (`A_F_CAKE_DESC`, 1 to 300, counter), `TextField` price (`A_F_PRICE`, whole dong, 1 to 100 000 000, suffix "đ"); `ToggleRow` `A_CAKE_ACTIVE_TOGGLE` with helper `A_CAKE_HIDDEN_HELP`; destructive `SecondaryButton` `A_REMOVE_CAKE` (text `color.destructive`); `BottomActionBar` `A_SAVE`; `NoticeText` `A_NEW_ORDERS_ONLY` under the price.
- Hide: switching off while it is the only active cake is refused at once: switch returns on and `Toast` `A_ERR_LAST_CAKE` (AC-34). The hide is saved with the form, not at once (so name and visibility save together).
- Remove: `ConfirmDialog` (Destructive) `A_REMOVE_TITLE` naming `{name}`, body `A_REMOVE_BODY` (earlier orders keep the cake; it cannot be restored, BR-19), buttons `A_REMOVE_YES`, `A_BACK`. The only active cake: refused with `A_ERR_LAST_CAKE` (the dialog is not opened). On success: `Toast` `A_CAKE_REMOVED`, back to S-A13 (AC-62, AC-63).
- Validation: name empty or taken by another cake `A_ERR_CAKE_NAME_DUP`; price `A_ERR_RANGE_INT` (AC-45); description `A_ERR_REQUIRED`/`A_ERR_TOO_LONG`.
- States: Default; Loading (skeleton); Empty N/A; Error (load: `StateView`; save: `InlineMessage`); Offline; Disabled (Save while unchanged or running; remove while saving); Success (save: `Toast` `A_SAVED`, back). Cake already removed by another session: `StateView` `A_CAKE_GONE` with `A_BACK_TO_LIST`.

### S-A15 Add cake

- Purpose: new cake with one picture (FR-38, BR-18, AC-60, AC-61). Entry: `A_ADD_CAKE` on S-A13 (disabled at 12).
- Layout: `TopBar` `A_ADD_CAKE_TITLE`; `ImagePickerField` (required); `GlassCard` with name, description, price fields as S-A14; `NoticeText` `A_NEW_CAKE_ACTIVE` ("Bánh mới sẽ hiện ngay với khách."); `BottomActionBar` `A_ADD_CAKE_SAVE`.
- Image: the native photo picker (no permission prompt) returns one picture. The app checks on the device before upload: type JPEG or PNG, size up to 5 MB (BR-18). Other formats: `A_ERR_IMG_TYPE`; larger: `A_ERR_IMG_SIZE`; the picture is not kept. Pictures the picker returns in another format (for example HEIC) are converted by the app to JPEG; whether to convert and compress is a technical question (TQ-D1). After a valid choice the preview shows with the text buttons `A_IMG_CHANGE` and `A_IMG_REMOVE_PICK`.
- Saving: the button shows `A_UPLOADING` with progress ("Đang tải ảnh… {percent}%") and the form is read-only; a `SecondaryButton` `A_CANCEL_UPLOAD` stops it and nothing is created. If the picture upload fails the form keeps all values and the picture and shows `InlineMessage` `A_ERR_UPLOAD` with a retry through the same button; no cake exists until the whole save succeeds (AC-61). After success: `Toast` `A_CAKE_ADDED`, back to S-A13 where the new cake is first in its group.
- Validation (all at once, naming the field): no picture `A_ERR_IMG_REQUIRED`; name empty or used `A_ERR_CAKE_NAME_DUP`; price `A_ERR_RANGE_INT`; description; 13th cake `A_ERR_CAKES_FULL` as `InlineMessage`.
- States: Default (empty form, Save disabled until all fields are filled and a picture is chosen); Loading (upload with progress); Empty N/A; Error; Offline (`A_OFFLINE_SAVE`; the form is kept); Disabled (Save until complete; the form while uploading); Success. Picture failed to load from the picker: `A_ERR_IMG_READ`.
- Leaving with any value or picture shows the Dirty back dialog of part 2.
