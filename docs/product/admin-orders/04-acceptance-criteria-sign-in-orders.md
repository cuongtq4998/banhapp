# Admin Orders: Acceptance Criteria, sign-in, list, detail (section 7, part 1)

Part of [Admin Orders](../admin-orders.md) (PRD v1.1). Holds: AC-1 to AC-30. Sample data is fake: owner "Chu Mau" chu.mau@example.com, staff "Nhan Vien A" nhanvien.a@example.com, unregistered khong.co@example.com, customer phones +84 900 000 0xx, orders BT-AAAAAA style codes. [v1.1 | 2026-10-31]

## 7. Acceptance Criteria

### 7.1 Sign-in and roles

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-1 | FR-1 | Given staff e-mail nhanvien.a@example.com is active, when it is submitted on the sign-in screen (also typed as NhanVien.A@Example.com), then a code is sent to that address and the screen asks for 6 digits. [v1.1 | 2026-10-31] |
| AC-2 | FR-1 | Given khong.co@example.com is not registered, when it is submitted, then the screen and the response are identical to AC-1 (same text, same code-entry step) and no e-mail is sent. [v1.1 | 2026-10-31] |
| AC-3 | FR-2 | Given a code was sent 1 minute ago, when the correct 6 digits are entered, then the person is signed in and sees the order list. |
| AC-4 | FR-2, BR-5 | Given a code was sent 11 minutes ago, when it is entered, then sign-in is refused with an "expired" message and no session exists. [v1.1 | 2026-10-31] |
| AC-5 | FR-2, BR-5 | Given a code was already used, when it is entered again, then sign-in is refused. |
| AC-6 | FR-3, BR-5 | Given a code was sent 10 seconds ago, then "resend" is disabled and shows the seconds left; after 30 seconds it is enabled; tapping it sends a new code and the old code no longer works. |
| AC-7 | FR-3 | Given the code step, when "change e-mail" is tapped, then the address entry shows again with the address kept for editing. [v1.1 | 2026-10-31] |
| AC-8 | FR-6, BR-5 | Given 5 wrong codes entered for one address, when a 6th code (even correct) is entered, then sign-in is refused with a message that says to try again in 15 minutes. [v1.1 | 2026-10-31] |
| AC-9 | FR-6, BR-5 | Given 3 codes were requested for one address in the last hour, when a 4th is requested, then it is refused with a message giving the wait. [v1.1 | 2026-10-31] |
| AC-10 | FR-4, BR-6 | Given a device last used 6 days ago, when the app is opened, then the order list shows without a code. Given last used 8 days ago, then the sign-in screen shows. [v1.1 | 2026-10-31] |
| AC-11 | FR-4 | Given a signed-in person, when "sign out" is tapped, then the sign-in screen shows and the previous session no longer works on the server. |
| AC-12 | FR-5, BR-1 | Given a signed-in staff account, when it asks the server to change a price, add or remove a cake, change lead days, add a district or add a staff account, then the server refuses every request and nothing changes. [v1.1 | 2026-10-31] |
| AC-13 | FR-5, BR-1 | Given no sign-in, when any order or settings data is requested, then the server refuses and returns no order data. |
| AC-14 | FR-7, BR-8 | Given staff account B is signed in on two devices, when the owner deactivates B, then at once neither device can renew its sign-in, and within 5 minutes both devices are refused data on their next request and show the sign-in screen. [v1.1 | 2026-10-31] |

### 7.2 Order list

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-15 | FR-8, BR-13 | Given orders: A New for 02/11, B Confirmed for 01/11, C Completed for 01/11, D New for 01/11 placed earlier than B, when the list opens with default filters, then C is absent and the order is D, B, A (date, slot, then placed time; the slot is the same). |
| AC-16 | FR-8 | Given an order, then its row shows code, customer name, status, delivery date and slot, number of cakes, total in dong and district. |
| AC-17 | FR-9 | Given orders in all four statuses, when only Cancelled is selected, then only Cancelled orders show; when all is selected, all four statuses show. |
| AC-18 | FR-10 | Given orders for 01/11, 02/11 and 05/11 and server date 01/11, when "today" is chosen, then only 01/11 orders show; "tomorrow" shows 02/11; range 01/11 to 02/11 shows both and not 05/11. |
| AC-19 | FR-11 | Given an order BT-AAAAAA, name "Tran Thi B", phone +84 900 000 010, when "AAAAAA", "Thi B" or "0900000010" is typed, then that order is in the result; when "zzz" is typed, then the empty state shows. |
| AC-20 | FR-12 | Given 3 orders in New, then the New count shows 3; when a customer places an order and the person pulls to refresh, then the count shows 4 and the list contains the new order. |
| AC-21 | FR-12 | Given the list screen, then it shows the time of the last successful update. |
| AC-22 | FR-13 | Given no orders match the filters, then an empty message shows. Given no connection, then an offline message and a retry action show and no older customer data is presented as current. Given a server error, then an error message and retry show. |
| AC-23 | BR-13 | Given 120 matching orders, then 50 load first, and 50 more load each time the end is reached, with no duplicate row. |

### 7.3 Order detail and status changes

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-24 | FR-14 | Given an order, when it is opened, then all fields listed in FR-14 show with prices as stored at the time of ordering, even if the cake price was changed afterwards. |
| AC-25 | FR-15 | Given an order, when "call" is tapped, then the phone dialer opens with the customer's number; when "Zalo" is tapped, then Zalo opens for that number, or a Vietnamese message says Zalo is not available. |
| AC-26 | FR-16 | Given a New order, when "confirm" is tapped, then its status is Confirmed in the detail and in the list, and the history shows the change with the account name. |
| AC-27 | FR-17, BR-2 | Given a Confirmed order whose delivery date is 5 days away, when "complete" is tapped, then its status is Completed and no status action remains. Given a New order, then no "complete" action is offered and a direct request is refused. [v1.1 | 2026-10-31] |
| AC-28 | FR-18, BR-3 | Given date 05/11 with limit 100 and 98 cakes accepted, and a New order of 4 cakes counted in the 98, when the order is cancelled with the reason "day full" and the confirmation naming its code is accepted, then the status is Cancelled and a customer asking for availability on 05/11 for 6 cakes gets that date as available. [v1.1 | 2026-10-31] |
| AC-29 | FR-18 | Given the cancel confirmation is shown, when "back" is chosen, then the status is unchanged. Given a Confirmed order, cancelling works the same as for New. Given no reason is chosen, then the cancel action is unavailable and a direct request without a reason is refused. [v1.1 | 2026-10-31] |
| AC-30 | FR-19, BR-2 | Given two staff open the same New order, when the first confirms and the second then cancels from the old view, then the second change is refused, the order stays Confirmed, and the second person is shown the current status and a message. Given a Completed or Cancelled order, then no status action is offered and a direct request to change it is refused. |
