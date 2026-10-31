# Admin Orders: Overview and Scope (sections 1 to 4)

Part of [Admin Orders](../admin-orders.md) (PRD v1.5). Holds: how a day works, Summary, Background, Goals G-1 to G-4, Non-goals, Users, decisions D-1 and D-2. Rewritten in v1.5 (simplification, owner directive 2026-10-31); every line below is new or changed in v1.5 [v1.5 | 2026-10-31].

## 0. How a day works (plain language) [v1.5 | 2026-10-31]

Design test for the whole feature (owner directive 2026-10-31): a shop owner or staff member must be able to use the app on the first day without being taught. If a rule needs explaining to them, it is simplified or kept invisible. [v1.5 | 2026-10-31]

### Staff member

1. Opens the app. First time on a phone: types the e-mail address the owner added, gets 6 digits by e-mail, types them. After that the app opens straight to the orders for the rest of the time the phone is used at least once a week. [v1.5 | 2026-10-31]
2. A phone buzzes: "New order BT-AAAAAA, 3 cakes, 05/11". Tap it: the order opens. [v1.5 | 2026-10-31]
3. Read the order, tap Call (or Zalo) to talk to the customer, tap Confirm. [v1.5 | 2026-10-31]
4. On delivery day open the list, choose Today, hand over the cakes, tap Complete and OK. [v1.5 | 2026-10-31]
5. If the customer cancels, open the order, tap Cancel, pick one of four reasons, tap OK. The cakes become available again. [v1.5 | 2026-10-31]
6. The Orders tab has a red number when orders are due today or overdue. The list already shows them first, marked in red. Open them and finish them. [v1.5 | 2026-10-31]

### Owner

Does everything a staff member does, plus: [v1.5 | 2026-10-31]

1. Settings has five plain entries: Cakes (add with a photo, change a price, hide, remove), Ordering (daily limit, days of notice, minimum cakes), Delivery (districts with fee, time slots), Shop info (name, greeting, phone, Zalo), Staff (add an e-mail, switch a person off or on). [v1.5 | 2026-10-31]
2. A change applies to new orders only; orders already placed never change. [v1.5 | 2026-10-31]
3. Lost phone: sign in on the new phone with one code, then tap "Sign out all other phones". If the owner can no longer open the owner mailbox, the operator helps outside the app (proposal P-1, Q-25). [v1.5 | 2026-10-31]

### Customer

Never uses this app. Orders as before, sees changed cakes and prices, and is contacted by phone or Zalo. [v1.5 | 2026-10-31]

### What users never see (invisible system behaviour)

Limits on codes, how long a code lives, how sign-in is renewed and protected, the 5-minute cut-off for removed people, the record of who changed what, the 90-day rule for finished orders, paging of 50 orders, store-review account. They are in the rules (03) and in the non-functional part (06) but no screen, button or message teaches them, except a short Vietnamese message when a limit is reached. [v1.5 | 2026-10-31]

## 1. Summary

The shop owner and staff sign in on their phones with an e-mail address and a one-time code, see the orders placed with [Place Order](../place-order.md), and move each order from New to Confirmed, Completed or Cancelled (a cancellation needs a reason). The owner also maintains what customers see (cakes, prices, districts and fees, time slots, daily limit, days of notice, minimum cakes, shop info) and decides who on the staff may sign in. Signed-in phones get a notification for each new order. The admin app is a separate app for iOS and Android on the same repository and backend (D-1, D-2). [v1.5 | 2026-10-31]

## 2. Background & Problem

Customers can place orders, but nobody on the shop side can see them. The shop must see new orders quickly, because the customer expects a call or Zalo message (Place Order A-4), must be able to cancel (cancelled cakes return to the date) and today cannot change shop values without a developer. [v1.5 | 2026-10-31]

## 3. Goals / Non-goals

### Goals

- G-1: A staff member sees a new order within 60 seconds of it being stored (measured on the server up to the hand-over to the Apple or Google push service) and opens it in 1 tap from the notification, or 2 taps from the app icon when it is among the first rows (AC-31). [v1.5 | 2026-10-31]
- G-2: An order moves New, Confirmed, Completed, or to Cancelled with 1 action and at most 1 confirmation step: Confirm has none, Complete one, Cancel one (reason chosen and confirmed in it) (AC-30). [v1.5 | 2026-10-31]
- G-3: The owner changes every shop value in FR-21 to FR-24 without a developer; a change alters 0 existing orders. [v1.5 | 2026-10-31]
- G-4: A person whose e-mail the owner has not added gets no access. A removed staff member's phones lose access to data within 5 minutes and cannot renew their sign-in. [v1.5 | 2026-10-31]

### Non-goals

- Payment handling (Place Order A-5); editing an order (Q-10: cancel, the customer orders again); notifying the customer by push, SMS or e-mail; SMS codes (Q-3); reports, statistics, exports, printing, routing; web admin, tablet layout, several shops; special dates, closed days, per-slot capacity; changing the 30-day booking horizon (Q-7); reminder notifications (Q-11); changing the image of an existing cake (add a new cake, remove the old one). [v1.5 | 2026-10-31]
- Everything in [08-deferred-and-id-mapping.md](08-deferred-and-id-mapping.md) section 1 (deferred in v1.5). [v1.5 | 2026-10-31]

## 4. Users

| Role | Description |
| ---- | ----------- |
| Owner | One person. Everything staff can do, plus settings and staff. One code to sign in (Q-18). [v1.5 | 2026-10-31] |
| Staff | Added by the owner, up to 30. Handles orders only; no settings, no staff list. [v1.5 | 2026-10-31] |
| Store reviewer | Apple or Google person; uses a fixed-code demo account with fake orders (FR-8). Not a real user. [v1.5 | 2026-10-31] |
| Customer | Not a user; affected by settings and by the shop's contact. [v1.5 | 2026-10-31] |

## Decisions of the owner

### D-1: separate admin app (decided, Q-1)

A separate app in the same repository on the same backend. It protects the customer promise "no account, no sign-in" (Place Order BR-7) and the customer release; it can be distributed to a small audience (S-2). Cost: two more store records and release pipelines. [v1.5 | 2026-10-31]

### D-2: iOS and Android at the same time (decided, Q-2)

Staff may own either phone (Android about 60 percent in Vietnam, S-4). Effort is about double; the owner accepted it. [v1.5 | 2026-10-31]
