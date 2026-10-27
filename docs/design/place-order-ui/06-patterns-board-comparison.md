# Place Order UI, part 6: Shared patterns and board comparison (sections 5.10, 5.11)

[v1.4 | 2026-10-27] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Content unchanged from v1.3; section numbers are the original ones.

### 5.10 Shared error and offline patterns

| Situation | Where | Behaviour |
| --------- | ----- | --------- |
| Data load fails (shop info, products, availability, districts) | S-2, S-3, S-4, S-5, S-6, S-7 | `StateView` Error or `InlineMessage` with the screen's key and `COMMON_RETRY`. Retry reloads only the failed data; entered flow data stays. [v1.1 | 2026-10-25] On S-2 to S-5 shop data, products and districts come from the cache when one exists (up to 7 days) and the Error state shows only without a cache. Availability (S-6) is never cached: offline there shows `DATE_ERR` with retry (ADR-0011). |
| No connection while loading | Same | Same pattern; the message names the network (`ERR_NETWORK_LOAD`). Nothing is entered into the order that depends on missing data. |
| No connection while sending | S-8 | `ERR_OFFLINE`, entered data kept, retry available (AC-20). |
| Server error or timeout while sending | S-8 | `ERR_SERVER` or `ERR_TIMEOUT`, entered data kept, retry available (FR-17). [v1.1 | 2026-10-25] Too many requests: `ERR_RATE_LIMITED`, same handling. |
| Price changed while sending | S-8 | [v1.1 | 2026-10-25] Updated review plus `MSG_PRICE_CHANGED`, confirm enabled (section 5.8). |
| Product or time slot no longer offered | S-8 | [v1.1 | 2026-10-25] `ERR_PRODUCT_UNAVAILABLE` (fix on S-5) or `ERR_SLOT_UNAVAILABLE` (fix on S-6); catalog is refreshed first. [v1.2 | 2026-10-26] For a hidden cake the data is kept and S-5 names the cake (`ORDER_CAKE_REMOVED`). |
| Zero active cakes | S-2, S-3, S-5 | [v1.2 | 2026-10-26] S-2 disables "Place order" with `HOME_NO_CAKES`; S-3 and S-5 show `PRODUCTS_EMPTY` with `COMMON_RETRY`. Different from a load failure (`PRODUCTS_ERR`). |
| Cake hidden while its detail is open | S-4 | [v1.2 | 2026-10-26] Gone state: `DETAIL_GONE` with `DETAIL_GONE_ACTION` back to S-3. |
| Connection returns | Any | No automatic send. The customer taps retry. A visible load error retries on `COMMON_RETRY` only. |
| App goes to background and returns | S-5 to S-8 | Flow data kept. [v1.1 | 2026-10-25] The draft is also saved on the device and survives the system ending the app, for up to 24 hours without change; it is restored when the customer taps "Place order" on S-2 (no prompt) and deleted after a confirmed order (ADR-0011). |

### 5.11 Board comparison and open points [v1.3 | 2026-10-26]

Slice 1 screens (S-1 to S-4) were compared with the board line by line. This table lists every difference and what this version did.

| Screen | Board shows | Earlier document | Action in v1.3 |
| ------ | ----------- | ---------------- | -------------- |
| S-1 | Logo only on the gradient and blobs; the whole screen is a link | Logo only, nothing tappable | Layout sizes taken from the board; link not copied (prototype device) |
| S-2 | Logo, shop name, greeting as plain text; two large cards ("Xem sản phẩm" glass first, "Đặt bánh" green second) with subtitles; two contact capsules with the numbers at the bottom | Greeting in a card; Place order button above View products in a bar; contact row | Document follows the board (5.2); new copy keys; subtitle count and numbers need BQ-4 confirmation but are specified because they are shop data |
| S-3 | Back button, large title, list rows with chevron, bar button "Đặt bánh" | No bottom bar | Bar added (5.3); BQ-5 asks for confirmation |
| S-4 | Hero picture, floating back button, glass card (name, price, description, two chips), bar button "Đặt bánh" | Title bar with the cake name; order of name, description, price; no chips; "Đặt bánh này" | Layout and order follow the board; button text changed to "Đặt bánh"; chips NOT specified (not in PRD, BQ-3) |
| All | Be Vietnam Pro / Roboto Flex, custom colours and glass values, no native navigation bar | System fonts, native bars | Design system v1.2; TQ-11 for fonts |

Later screens on the board (screens 4 to 7 and A1 to A4) differ from the approved PRD in structure. They are not specified here; the visual styling already follows `design-system.md` v1.2 and their structure stays as in sections 5.5 to 5.9 until the questions below are answered. This is the board content and what it implies:

| Board screen | Board content | Differs from PRD v1.4 / this document | Implied new or changed items |
| ------------ | ------------- | ------------------------------------- | ---------------------------- |
| 4 Choose cakes ("Chọn bánh tét", step 1 of 3) | One glass row per cake: 68 pt / 64 dp thumbnail, name, description, price, stepper; bar with "Tổng số bánh {n} cái" and "Tiếp tục" (disabled label "Chọn ít nhất 1 cái" when the total is 0) | No subtotal card and no `QTY_MIN_HINT` message (the disabled button label explains the rule); the prototype caps at 20 per cake (ADR-0009 says 99); "1" in the label is the minimum, which is configuration (MIN_QTY) | New keys for the bar total and the disabled label with `{min}`; move the total into the bar; decide whether the subtotal stays |
| 5 Delivery ("Giao hàng", step 2 of 3) | One screen: day chips for the next five days (weekday letters CN, T2 to T7 and the day number), three time slot chips ("7:00–10:00", "10:00–14:00", "14:00–18:00"), then recipient fields (name, phone, one address line whose placeholder names district), button "Xem lại đơn" | PRD has a month calendar with capacity, lead days and horizon (FR-6, BR-1, BR-2, BR-8), a separate recipient step, a district picker with flat fee (FR-8, BR), a note field (FR-18) and four steps; the board has five fixed days, no district picker, no fee line, no note | See queries Q-S1 to Q-S5 below |
| 6 Review ("Xem lại đơn", step 3 of 3) | Rows "name × n", "Tạm tính", "Phí giao hàng", "Tổng cộng"; one "Giao hàng" card with a single "Sửa" link and rows "Nhận hàng", "Người nhận", "Địa chỉ"; button "Đặt bánh" | No privacy sentence (PRD section 8), no note row, no separate edit links per block, no error banner states, button text "Đặt bánh" instead of "Xác nhận đơn hàng" | Q-S6 |
| 7 Success ("Đặt bánh thành công") | Check mark; "Cảm ơn bạn. Cửa hàng sẽ liên hệ qua số điện thoại để xác nhận đơn."; card with "Mã đơn", "Nhận hàng", "Địa chỉ"; button "Về trang chọn bánh" (iOS) or "Về trang chủ" (Android) | PRD AC-15 and AC-25 and section 5.9: no recap, wording "received" not "accepted"; FR-12 asks Zalo and phone buttons here; the board has none; the two platforms of the board disagree on the button target | Q-S7 |
| A1 Admin sign in | Phone number step, then 6-digit OTP step with a resend timer ("Gửi lại sau [30]s"), "Đổi số", remember-login note with N days, text that only phones added by the owner can sign in | Staff and owner apps are outside this feature (PRD non-goals); no authentication exists in the PRD or ADRs | Q-A1 |
| A2 Admin orders | Title "Đơn hàng"; four status tabs (Mới, Xác nhận, Hoàn thành, Hủy); order cards with code, status badge, customer name, date and slot, count, total, district, a "Gọi khách" button; bottom tab bar (Đơn hàng, Cài đặt) | Order status and cancellation are non-goals for the customer app; no staff features exist | Q-A2 |
| A3 Admin order detail | Code and status badge; customer card with "Gọi [number]" and "Nhắn Zalo"; delivery card; cakes card with fee and total; buttons "Hủy đơn" (destructive) and "Xác nhận đơn" | BR-9 and AC-28 (cancellation) exist only as business rules without UI | Q-A2 |
| A4 Admin settings | Six rows: products and prices (on/off per cake), districts and fees, order limits (cakes per day, lead days, minimum per order), time slots, shop information, staff (add, lock); note that rows show for the owner only; sign out | Configuration is a launch-data table in the PRD, not an in-app feature | Q-A3 |

Queries (details in the report to the orchestrator; ids used by scribe-requirements and atlas-architect):

- Q-S1 (scribe) Three steps on the board against four in the PRD (G-1 allows at most 6): which wins? The board merges date, time and recipient.
- Q-S2 (scribe, atlas) Five fixed days against a month calendar: how do lead days, horizon and daily capacity (BR-1, BR-2, BR-8) show on a five-day strip, and what happens when fewer than five days are available or the strip ends?
- Q-S3 (scribe, atlas) District and fee: the board has no district picker or fee on the delivery step but shows "Phí giao hàng" on review. Is the district part of the single address line, or kept as a field?
- Q-S4 (scribe) Note field (FR-18) is absent from the board delivery step.
- Q-S5 (scribe) Time slots: the board shows three in a row; the number of slots is configuration. Row (wrap or scroll when more than three) or list?
- Q-S6 (scribe) Review: privacy sentence, note row, "Tạm tính" line and one edit link: keep, add or drop?
- Q-S7 (scribe) Success: recap rows, wording "thành công" and "xác nhận đơn", and the missing Zalo and phone buttons against AC-15, AC-25 and FR-12; home button target.
- Q-A1 to Q-A3 (scribe, atlas) Admin sign-in by SMS code (a paid message service, owner money question), roles (owner and staff), order status flow and cancellation, settings editor: all outside the first slice; new PRD and ADRs are needed before any design work.
