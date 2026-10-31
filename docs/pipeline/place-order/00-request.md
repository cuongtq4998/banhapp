# Request: Place Order

| Field | Value |
| ----- | ----- |
| Slug | place-order |
| Type | new-project (first feature slice) |
| Date | 2026-10-25 |
| Source | Product owner interview, translated to English and compiled; wording of rules is the owner's |

## Description (owner's intent)

A small shop sells traditional Vietnamese sticky-rice cakes (banh tet) for pre-order. Customers use a mobile app (iOS and Android) to place orders. The first slice to build is **a customer places an order**. Shop-side order handling and staff login are separate later features.

**Products (fixed set of four):** banana; mung bean with pork fat (dau mo); vegetarian mung bean (dau chay); mung bean with salted egg yolk and pork fat (dau trung muoi mo). Prices are set by the shop and may change.

**Customer journey:**
1. Opening the app shows a logo-only launch screen, then the home screen.
2. The home screen shows the shop name, a short greeting, contact buttons (Zalo and phone), and two prominent buttons: "View products" and "Place order".
3. "View products" shows the list of four cakes with picture, name, short description and price, and a detail view for each, with a button to place an order.
4. "Place order": choose cakes and quantities; choose the receiving date and time; enter the delivery address (delivery to the door); review the order; confirm.
5. After confirming, the customer sees only a confirmation screen with an order code. Afterwards the customer contacts the shop through Zalo or phone. There is no order tracking or cancellation in the app.

**Customer identity:** no account. The order is made with name, phone number and address.

**Ordering rules (values to be provided by the shop):**
- A maximum number of cakes per day; a day that is full cannot be chosen.
- A minimum lead time of N days between ordering and receiving.
- Delivery only to certain districts; the delivery fee depends on the district.
- A minimum total quantity per order.

**Payment:** not decided; no online payment in this slice.

**Look and feel:** modern and native on each platform: Liquid Glass on iOS, Material 3 Expressive on Android. Customer-facing text is Vietnamese.

**Out of this slice (later features):** staff and owner login by phone number with a one-time code; order list and status handling for staff (New, Confirmed, Completed, Cancelled); owner configuration of products, prices, districts and fees, daily limit, time slots, shop information and staff; push notifications.

## Who benefits

Customers placing orders; the shop owner, who needs orders to arrive without exceeding what the shop can make.

## Constraints

- Public repository: fake data only; no secrets.
- Small shop: low cost, simple operation.
- Existing assets: UI mockups of all screens exist in the design canvas at `https://claude.ai/artifact/HcWoUjBbqA9B1WUvZ3RKCb` (reference only; text specs are authoritative).

## Existing docs

None under `docs/product/` yet.

## Unknown (do not invent)

Value of N (lead days); daily cake limit; minimum quantity per order; list of served districts and fees; delivery time slots; cake prices; shop name, greeting, Zalo and phone contacts.
