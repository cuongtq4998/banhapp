# Place Order: Change Log (section 13)

Part of [Place Order](../place-order.md) (PRD v1.4.1). [v1.4.1 | 2026-10-27]

## 13. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version (Draft). |
| 1.1 | 2026-10-25 | Owner accepted proposed defaults for Q-1 to Q-14; all marked Answered. Changed FR-4, FR-6, FR-7, FR-9, FR-10, FR-11; added FR-18, FR-19. Changed BR-1 to BR-5, BR-7; added BR-8 to BR-12. Changed AC-5, AC-7 to AC-11, AC-13, AC-15; added AC-24 to AC-29. Changed G-2, non-goals, assumptions (A-3 removed, A-4, A-5 changed, A-8 added), privacy and dependencies text. Added section 12.1 launch data. Status In review. |
| 1.2 | 2026-10-25 | Owner approved v1.1 and confirmed: currency VND in whole dong (BR-5, now a confirmed fact); sample values marked as sample only in the data source, no visible marker in the app (AC-29, Q-8, 12.1). Added testability note to AC-28 (BR-9 needs cancellation to exist). Status Approved. |
| 1.3 | 2026-10-25 | Clarifications only; no owner-decided number or rule changed, Status stays Approved (v1.2). Closed Q-T1 to Q-T6 with ADR references. Server date in shop time zone for BR-2, AC-7, AC-24, A-8 (controllable clock). Database-level evidence for AC-15, AC-23, AC-28, BR-9. BR-4 technical bound of 99 per cake stated as not a business maximum. AC-29 no marker word; AC-21 scope limited to app-owned text. Launch screen time is guidance (A-9); verdict rules (Should-linked AC-17, AC-26 do not block Pass). Added FR-20, FR-21, AC-30, AC-31 and section 12.2 pending owner confirmation, with owner questions Q-O1 to Q-O5. |
| 1.4 | 2026-10-26 | Owner decision on fewer than four active cakes (Q-15, answers QA DOC-8): 1 to 4 active cakes are normal, Error state only at zero. Changed summary, non-goal, FR-3, FR-5, BR-1, AC-4, 12.1; added BR-13, AC-32 to AC-34, Q-15. Clarified AC-29 scope (customer-visible text only; "mẫu" counts as a marker word in displayed values; technical documents may use it) and Q-O5 default (answers QA DOC-6). |
| 1.4.1 | 2026-10-27 | Split into files of at most 200 lines; no requirement changed. The document is now an index (docs/product/place-order.md) plus seven parts in docs/product/place-order/. Section numbers and all ids (G, FR, BR, AC, A, S, Q, N) are unchanged; Status unchanged. |
| 1.5 | 2026-10-29 | Owner decision: privacy notice shown on S-7 (recipient screen); FR-20 and FR-21 confirmed as written. FR-20 and AC-30 reworded (full notice as a card on S-7 visible before the first field is edited; S-8 keeps a one-sentence reminder with link); FR-21 and AC-31 no longer pending; N-1 and N-2 Answered; privacy text in part 05 updated. |
