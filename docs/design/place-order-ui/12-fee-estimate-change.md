# Place Order UI, part 12: Delivery fee as an estimate (change of 2026-11-02)

Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Based on product/place-order.md v1.7 (BR-3, BR-5, BR-9, FR-9, AC-11, AC-14, AC-28) and admin-orders v1.10 (BR-15, BR-11). New in v1.7. Where this part differs from parts 5 and 8, this part wins; parts 5 and 8 carry a pointer. [v1.7 | 2026-11-02]

## 1. What changes for the customer

The customer no longer sees a fixed fee or a total with fee. The district fee is shown as an estimate, with one line saying the final fee is told at delivery, and the customer pays the cakes plus the real fee at handover (payment itself stays outside the app, AC-27 unchanged). No screen shows a sum of cakes plus fee. [v1.7 | 2026-11-02]

## 2. Screen changes

| Screen | Element before | Element now | FR, AC |
| ------ | -------------- | ----------- | ------ |
| S-7 Recipient, district picker row | `DISTRICT_FEE` "Phí giao hàng: {amount}" | `DISTRICT_FEE_ESTIMATE` "Phí giao dự kiến: {amount}"; same in the picker sheet rows | FR-8, AC-11 |
| S-7, under the district field once a district is chosen | none | `NoticeText` `FEE_NOTICE` (one line, `type.caption`, `color.onSurfaceVariant`) | AC-11 |
| S-8 Review, totals card | `REVIEW_FEE` and `REVIEW_TOTAL` (sum) | `SummaryRow` `REVIEW_CAKES_TOTAL` (sum of cakes), `SummaryRow` `REVIEW_FEE_ESTIMATE` with the estimate (muted), `NoticeText` `FEE_NOTICE`; no total with fee | FR-9, BR-5, AC-14 |
| S-9 Confirmation | total, if shown | cakes total only plus `FEE_NOTICE`; no fee amount as final | AC-28 |

- The estimate row is visually secondary (`type.body`, muted) to the cakes total (`type.body.strong`) so it is not read as part of the total. The text "dự kiến" is in the label itself, not only a tag. No icon-only or colour-only signal.
- District with an estimate changed by the shop between S-7 and S-8: the estimate shown follows the catalog; it is not a price change, so `MSG_PRICE_CHANGED` does not appear for the fee alone (assumption, question PQ-1 for the architect and scribe: does the server still return 409 `PRICE_CHANGED` when only the estimate changed?). A changed cake price still triggers it, and the changed amounts are highlighted as before.
- States: unchanged. Error `DISTRICT_ERR` and `DISTRICT_EMPTY` keep working; with a district chosen and the estimate missing from the answer the row shows `FEE_UNKNOWN` ("Phí giao báo khi giao") and the order may still be sent (assumption, PQ-2).
- Portrait and landscape: no layout difference; the notice wraps to two lines at large text; all fixed bars keep their safe areas.
- Accessibility: the estimate row is read as "Phí giao dự kiến {amount}", the notice is read directly after it as part of the same group; the cakes total is read first on S-8. Dynamic type: rows wrap.

## 3. Copy keys

| Key | Vietnamese | Meaning (English) |
| --- | ---------- | ----------------- |
| `DISTRICT_FEE_ESTIMATE` | Phí giao dự kiến: {amount} | Estimated delivery fee (replaces `DISTRICT_FEE`) |
| `FEE_NOTICE` | Phí giao hàng chính thức sẽ được báo khi giao. Bạn thanh toán tiền bánh và phí giao thực tế khi nhận hàng. | Final fee told at delivery; pay cakes and real fee at handover |
| `REVIEW_CAKES_TOTAL` | Tiền bánh | Cakes total (replaces `REVIEW_TOTAL`) |
| `REVIEW_FEE_ESTIMATE` | Phí giao dự kiến | Estimate row label (replaces `REVIEW_FEE`) |
| `FEE_UNKNOWN` | Phí giao báo khi giao | Fee told at delivery (no estimate) |

Deleted keys: `DISTRICT_FEE`, `REVIEW_FEE`, `REVIEW_TOTAL`. The English column is for reviewers only: the customer app has one locale, Vietnamese. Wording is a draft for the native review.

## 4. Test identifiers

`order.district.fee` keeps its id and now holds the estimate text; `review.fee` holds the estimate row; `review.total` is renamed `review.cakesTotal`; new `order.fee.notice` and `review.fee.notice`. Platform deviation notes (part 9b) are the developers' to update. [v1.7 | 2026-11-02]

## 5. Traceability

BR-3, FR-8: S-7 estimate. BR-5, FR-9, AC-14: S-8 totals. AC-11: S-7 notice. AC-28: S-9 and S-8 without a total with fee. BR-9: the requested date still holds capacity (no UI change in S-6). The customer is not shown the expected date in the app (no FR asks for it; question PQ-3 for the scribe: should the customer see it?).
