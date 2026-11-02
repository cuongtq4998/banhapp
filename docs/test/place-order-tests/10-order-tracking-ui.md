# Place Order: Tests for Order Tracking and Lookup, Client Side (part 10)

Part of [place-order-tests.md](../place-order-tests.md) (v1.9). Section 4.9 (new in v1.9 [v1.9 | 2026-11-02]) for FR-22 to FR-27, BR-15 to BR-18, AC-38 to AC-48 (08-order-tracking). Backend security and shape tests are in admin-orders part 18 (TC-B601 to TC-B639). Early mode: all `Not run`. Levels: UI iOS, Android (both platforms each), API contract. Fake phones only.

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-P201 | acceptance | UI iOS, Android | AC-38, FR-22 | Order at Processing: open tracking | Step 2 of 5 marked, step 1 done; code, cakes (2 x 120 000 = 240 000), requested date and slot shown |
| TC-P202 | acceptance | UI iOS, Android | AC-38 | Each of the other statuses (Received, S, D) | Step marked matches; Cancelled is not one of the five steps |
| TC-P203 | acceptance | UI iOS, Android | AC-42 | Finished | Five steps done, "finished" text, no action |
| TC-P204 | acceptance | UI iOS, Android | AC-39, FR-23 | No expected date, then 12/11 | Text "shop will schedule" and only requested date; then "Expected 12/11" with the may-move note and the requested date |
| TC-P205 | extra | UI iOS, Android | AC-39 | Expected date moves, then screen refreshed | Latest date only; no old date |
| TC-P206 | extra | UI iOS, Android | FR-23 | Copy check of the may-move wording (DOC-5 owner canvas-ui) | Text equals the design spec; blocked until the strings exist |
| TC-P207 | acceptance | UI iOS, Android | AC-40, FR-24 | Estimate 20 000, no real fee | "about 20 000 (final fee told at delivery)"; no amount to collect |
| TC-P208 | acceptance | UI iOS, Android | AC-40 | Real fee 25 000 | Fee 25 000, amount to collect 265 000 |
| TC-P209 | acceptance | UI iOS, Android | AC-41 | Fee corrected 25 000 to 30 000; pull to refresh | Shows 30 000 and 270 000; 25 000 nowhere (also not in accessibility labels) |
| TC-P210 | boundary | UI iOS, Android | FR-24 | Real fee 0 | "Free delivery" or 0; amount to collect equals the cakes; not shown as missing |
| TC-P211 | acceptance | UI iOS, Android | AC-43, FR-27 | Cancelled with reason "fake or spam order" | "Cancelled" and shop contact (Call, Zalo); the reason text nowhere; no cancel or refuse button |
| TC-P212 | acceptance | UI iOS, Android | AC-44, FR-25 | Type a fake phone with orders | List opens; no sign-in and no code asked |
| TC-P213 | acceptance | UI iOS, Android | AC-45 | Two orders (08/11, 10/11) | 10/11 first, each with code and status; open one shows tracking |
| TC-P214 | acceptance | UI iOS, Android | AC-45 | Phone without orders | Empty state, no error styling |
| TC-P215 | negative | UI iOS, Android | AC-48 | Bad phones: letters, short, long, empty | Same message and shape in all; the request is not sent for empty (client side) or sent and 422 handled |
| TC-P216 | negative | UI iOS, Android | AC-44, BR-17 | Exceed the hourly limit (429) | Wait message with the time from `Retry-After`; same text whether or not the phone has orders; no list shown |
| TC-P217 | extra | UI iOS, Android | AC-47 | Phone display and address | "0900 000 ***" style mask; district only; no street or ward; no staff name, record or reason |
| TC-P218 | boundary | UI iOS, Android | BR-18, AC-47 | Order Finished 31 days ago | Not listed, not found |
| TC-P219 | extra | UI iOS, Android | FR-25 | 12 orders: paging, 5 pages max | "Load more" works until page 5 and then ends; no duplicates; no more than 50 |
| TC-P220 | extra | UI iOS, Android | FR-26, AC-46 | Connection lost after opening | Last data stays with read time and an offline notice; no error screen; after reconnect and refresh data is current |
| TC-P221 | extra | UI iOS, Android | FR-26, AC-46 | Pull to refresh counts against the limit | A refresh at the limit shows the wait message, keeps old data and read time |
| TC-P222 | negative | UI iOS, Android | AC-48, BR-17 | Compare screens: phone with orders, no orders, unused phone | Error text, wait message and layout identical except the list content |
| TC-P223 | negative | UI iOS, Android | BR-16 | Search data held on the device: stored phone, cache, screenshots, app switcher, logs | No order list stored in cleartext after the app is closed; phone not written to device logs (record what is stored; Blocked if not inspectable) |
| TC-P224 | extra | UI iOS, Android | BR-15 | The screen has no edit, confirm, cancel or refusal control | None present; accessibility tree checked |
| TC-P225 | extra | UI iOS, Android | FR-22 | Own order after placing it: confirmation links to tracking (Q-P5 answer) | Opens the same screen; if no link exists, record as question |
| TC-P226 | extra | UI iOS, Android | FR-27 | Shop contact buttons (Call, Zalo) at Cancelled and at other statuses | Values come from the catalog; none hard-coded |
| TC-P227 | extra | UI iOS, Android | 10.14.1 | Legacy status word in a stale cache | Never shown; unknown status falls back to a neutral text, no crash |
| TC-P228 | extra | UI iOS, Android | AC-38 | Large text size, narrow width, long cake name, 10 items | No clipped step text or amounts; scrolls |
| TC-P229 | extra | UI iOS, Android | FR-25 | Phone typed with spaces, dots and "+84" | Normalised on send; accepted; display shows the mask |
| TC-P230 | extra | API contract | 10.14.8 | iOS and Android decoders on all `order-lookup-*` and error fixtures | Decode with no unknown-key failure; null fields handled; same result on both platforms |
| TC-P231 | extra | UI iOS, Android | BR-17 | Rapid repeat taps on Search | One request in flight; no double count of the limit |
| TC-P232 | extra | UI iOS, Android | FR-25 | 503 and timeout | Retry message; no data of another phone shown; list cleared on a new phone |
