# Place Order: Overview and Scope (sections 1 to 4)

Part of [Place Order](../place-order.md) (PRD v1.6). Holds: Summary, Background & Problem, Goals G-1 to G-3, Non-goals, Users & Scenarios. [v1.6 | 2026-10-31]

## 1. Summary

A customer of a small banh tet pre-order shop uses a mobile app (iOS and Android) to browse the shop's active cakes (four at launch, at most 12 once the shop adds cakes, Admin Orders BR-18) [v1.6 | 2026-10-31] and place an order for delivery on a chosen date and time. No account [v1.4 | 2026-10-26] is needed. The app ends with a confirmation screen showing an order code; all later contact happens by Zalo or phone.

## 2. Background & Problem

The shop sells traditional Vietnamese sticky-rice cakes (banh tet) on pre-order and can make only a limited number per day. Orders must arrive in a form the shop can plan around: enough lead time, within daily capacity, to a served district, and with a worthwhile quantity. Customers need a simple way to see the products and order without registering. This is the first slice; shop-side order handling is a later feature.

## 3. Goals / Non-goals

### Goals

- G-1: A customer can go from app launch to a confirmed order in at most 6 steps after tapping "Place order" (cakes, date and time, address, review, confirm) without creating an account.
- G-2: No accepted order breaks any ordering rule (BR-1 to BR-4, BR-8): 0 orders accepted that exceed the daily limit, violate lead time or the 30-day horizon, target an unserved district or fall below the minimum quantity. [v1.1 | 2026-10-25]
- G-3: Every confirmed order gets an order code that the customer can quote to the shop.

### Non-goals

- Online payment and any payment text in the app; payment happens outside the app (Q-9, answered). [v1.1 | 2026-10-25]
- Order tracking, status display or cancellation in the app.
- Customer accounts, login, order history.
- Staff and owner features: login by phone with one-time code, order list and statuses (New, Confirmed, Completed, Cancelled), owner configuration of products, prices, districts and fees, daily limit, time slots, shop information, staff; push notifications.
- Pickup at the shop (only delivery to the door is requested).
- More than 12 products, or product variations (changed from "more than four" by Admin Orders Q-17). [v1.6 | 2026-10-31]
- Special dates (e.g. Tet) with different limits, lead times or closed days: rules apply uniformly in this slice (Q-11). [v1.1 | 2026-10-25]
- Free delivery or delivery fee discounts. [v1.1 | 2026-10-25]

## 4. Users & Scenarios

| Role | Description |
| ---- | ----------- |
| Customer | Anyone ordering cakes; identified only by name, phone number and address. |
| Shop owner / staff | Not a user of this feature. Receives the orders in a later feature; affected by the rules. |

Scenarios:

1. Browse then order. The customer opens the app, taps "View products", reads a cake detail, taps the order button there, and completes an order.
2. Direct order. The customer taps "Place order" on the home screen, chooses cakes, date, time, enters address, reviews and confirms.
3. Blocked choice. The customer tries a date that is full, too soon, or an unserved district and is told why and can change the choice.
