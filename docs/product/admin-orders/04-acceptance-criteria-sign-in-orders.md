# Admin Orders: Acceptance Criteria, sign-in, list, detail (section 7, part 1)

Part of [Admin Orders](../admin-orders.md) (PRD v1.5). Holds: AC-1 to AC-31 (old ids in [08-deferred-and-id-mapping.md](08-deferred-and-id-mapping.md)). Sample data is fake: owner "Chu Mau" chu.mau@example.com, staff "Nhan Vien A" nhanvien.a@example.com, unregistered khong.co@example.com, phones +84 900 000 0xx, codes BT-AAAAAA. Every line is new or changed in v1.5 [v1.5 | 2026-10-31].

## 7. Acceptance Criteria

### 7.1 Sign-in, access, staff

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-1 | FR-1, BR-4 | Given nhanvien.a@example.com is active, when it is submitted (also as NhanVien.A@Example.com), then a code is sent and 6 digits are asked. Given khong.co@example.com is not registered, then the screen and response are identical and no mail is sent. [v1.5 | 2026-10-31] |
| AC-2 | FR-1, BR-4 | Given a code sent 9 min 59 s ago, when the right digits are entered, then the person is signed in and sees the list; at 10 minutes or later, or if the code was already used, it is refused. The owner needs this one code only. [v1.5 | 2026-10-31] |
| AC-3 | FR-1, BR-4 | Given a code sent 10 seconds ago, then "resend" is disabled with the seconds left; after 30 seconds a new code can be requested and the old one stops working. "Change e-mail" returns to the address entry with the address kept. [v1.5 | 2026-10-31] |
| AC-4 | FR-1, FR-6, BR-4 | Given 5 wrong entries, then the code is void even for its right digits and a new one must be requested (no lock wait). Given 3 codes requested in the last 60 minutes, then a 4th is refused with the wait. A phone already signed in stays signed in throughout. Unregistered addresses behave the same. [v1.5 | 2026-10-31] |
| AC-5 | FR-2, BR-5 | Given a phone used every 5 days for 20 days, then it never asks for a code. Given a phone unused for 6 days 23 hours 59 minutes, then the list shows without a code; at 7 days or more the sign-in screen shows. [v1.5 | 2026-10-31] |
| AC-6 | FR-2 | Given a signed-in person, when "Sign out" is tapped, then the sign-in screen shows and the old session no longer works. [v1.5 | 2026-10-31] |
| AC-7 | FR-4 | Decided P-2. Given a person signed in on two phones, when "Sign out all other phones" is tapped on one, then the other cannot renew at once, loses data access within 5 minutes and shows the sign-in screen; this phone keeps working. [v1.5 | 2026-10-31] |
| AC-8 | FR-3, FR-20, BR-1 | Given a staff account, then no Settings or Staff entry exists and the server refuses (nothing changes) a price change, cake add or remove, ordering change, district add or staff add. Given no sign-in, then any order or settings request is refused and returns no data. Given the owner, Settings shows. [v1.5 | 2026-10-31] |
| AC-9 | FR-5, BR-6, BR-4 | Given the owner adds "Nhan Vien C" nhanvien.c@example.com, then that address can sign in as staff and the list shows name and e-mail. An address already used (any letter case), "a@b" or "a b@example.com" is refused naming the e-mail. Given 30 active staff, a 31st is refused with a message to switch one off first. [v1.5 | 2026-10-31] |
| AC-10 | FR-5, BR-6 | Given staff B signed in on two phones, when the owner switches B off, then neither phone can renew at once and both lose data within 5 minutes. Switching B on again (fewer than 30 active) lets B sign in, and old records still show B's name; at 30 it is refused. There is no way to switch off the owner. [v1.5 | 2026-10-31] |
| AC-11 | FR-6, BR-5 | Given a renewal already done, when its old credential is presented more than 20 seconds later, then the phone is signed out. Given the same renewal request is repeated within 20 seconds, then it succeeds and the phone stays signed in. [v1.5 | 2026-10-31] |
| AC-12 | FR-7, BR-13 | Given the owner signs in with a code on a phone not used before, then one notice goes to chu.mau@example.com with phone model and time and no code. Given a renewal, a staff sign-in or a mail failure, then no notice is sent and sign-in is not blocked. [v1.5 | 2026-10-31] |
| AC-13 | FR-8, BR-14 | Given the review account is on, when review.demo@example.com enters its fixed code, then it signs in as staff and sees exactly 3 demo orders and no real one, no real account sees a demo order, it gets no notification, and demo orders change no limit. Given it is off, the fixed code is refused like an unregistered address. [v1.5 | 2026-10-31] |

### 7.2 Order list

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-14 | FR-9, BR-9 | Given A New for 02/11, B Confirmed for 01/11, C Completed for 01/11, D New for 01/11 placed before B, when the list opens, then it shows D, B, A and not C. [v1.5 | 2026-10-31] |
| AC-15 | FR-9, BR-7 | Given an order, then its row shows code, name, status, date and slot, cakes, total and district, and not the phone, address or note. [v1.5 | 2026-10-31] |
| AC-16 | FR-9, BR-9 | Given today 10/11: A New for 08/11, B Confirmed for 10/11, C New for 11/11, D Completed for 08/11, E Cancelled for 09/11, then the list shows A (red "overdue 2 days"), B (red "due today"), C (no mark) and, after choosing All, D and E. [v1.5 | 2026-10-31] |
| AC-17 | FR-13, BR-9 | Given A and B of AC-16 plus one more overdue order, and C for a later date, the Orders tab shows a red "3" (C is not counted); with 0 no badge; with 120 "99+". After one is completed the number drops without reopening the app. [v1.5 | 2026-10-31] |
| AC-18 | FR-10 | Given all four statuses, when only Cancelled is chosen, then only Cancelled orders show; "All" shows all. Given orders for 01/11, 02/11, 05/11 and today 01/11, then "today" shows 01/11, "tomorrow" 02/11, a chosen date 05/11 only. [v1.5 | 2026-10-31] |
| AC-19 | FR-11, BR-10 | Given BT-AAAAAA, "Trần Thị Bé", +84 900 000 010, then "aaaaaa", "tran thi" and "0900000010" each find it; "zzz" shows the empty state; "ab" runs no search and says 3 characters are needed. [v1.5 | 2026-10-31] |
| AC-20 | FR-12 | Given the list, when a customer orders and the person pulls down, then the new order appears. Given no match, offline or a server error, then a Vietnamese empty, offline or error message with retry shows and no old customer data is shown as current. [v1.5 | 2026-10-31] |
| AC-21 | FR-9, BR-9 | Given a Completed order placed 89 days ago and one placed 91 days ago (by timestamp: exactly 90 days still shown), then list and search show the first and never the second, and a direct request for the second is refused, for the owner too. [v1.5 | 2026-10-31] |
| AC-22 | FR-9, BR-9 | Given a New order placed 100 days ago for a date 75 days ago, then it is in the default list marked overdue, can be opened and cancelled with a reason or confirmed and completed, and once Completed or Cancelled it is gone for everyone. [v1.5 | 2026-10-31] |
| AC-23 | BR-9 | Given 120 matching orders, then 50 load first and 50 more at the end of the list, with no row shown twice. [v1.5 | 2026-10-31] |

### 7.3 Order detail and status

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-24 | FR-14 | Given an order confirmed by "Nhan Vien A" after the cake price changed, then the detail shows all FR-14 fields with prices as stored and the line "last changed by Nhan Vien A, <time>". A cancelled order also shows its reason. [v1.5 | 2026-10-31] |
| AC-25 | FR-15 | Given an order, when Call is tapped the dialer opens with the number; when Zalo is tapped Zalo opens for it, or a Vietnamese message says it is not available. [v1.5 | 2026-10-31] |
| AC-26 | FR-16, BR-3 | Given a New order, when Confirm is tapped (no confirmation), then it is Confirmed in detail and list and a record exists with old and new status, account name and time. [v1.5 | 2026-10-31] |
| AC-27 | FR-17, BR-2 | Given a Confirmed order for a date 5 days away, when Complete is tapped and the confirmation naming the code is accepted, then it is Completed with no status action left; if declined, unchanged. A New order offers no Complete and a direct request is refused. [v1.5 | 2026-10-31] |
| AC-28 | FR-18, BR-2, BR-8 | Given date 05/11, limit 100, 98 cakes accepted including a New order of 4, when it is cancelled with a reason and confirmed, then it is Cancelled and a customer asking for 6 cakes on 05/11 gets the date. Exactly four reasons are offered; with none chosen Cancel is unavailable and a direct request is refused; "back" leaves the status unchanged; Confirmed orders cancel the same way. [v1.5 | 2026-10-31] |
| AC-29 | FR-19 | Given two staff open the same New order, when the first confirms and the second cancels from the old view, then the second is refused and sees Confirmed. Given Confirm is sent twice, then both show Confirmed, one record exists. Given a second cancel with another reason, then it succeeds as a repeat and keeps the first reason. A Completed or Cancelled order cannot be changed to another status. [v1.5 | 2026-10-31] |
| AC-30 | G-2 | Confirm needs 1 tap and no confirmation. Complete needs 1 tap plus 1 confirmation. Cancel needs 1 tap plus 1 screen where the reason is chosen and confirmed. No change needs a second confirmation. [v1.5 | 2026-10-31] |
| AC-31 | G-1, FR-26 | Given a signed-in phone, when the new-order notification is tapped, the detail opens (1 tap); with the app closed, icon then the row of that order in the default list opens it (2 taps). [v1.5 | 2026-10-31] |
