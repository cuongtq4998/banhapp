# Place Order: UI Specification (index)

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.9 [v1.9 | 2026-11-02]                                              |
| Last updated | 2026-11-02                                                            |
| Status       | Draft                                                                 |
| Owner        | canvas-ui                                                             |
| Based on     | product/place-order.md v1.10 (customer order tracking approved by the owner 2026-11-02) [v1.9 | 2026-11-02] |
| Related      | design/design-system.md (v1.2; index of design/design-system/); design/reference/ (owner's design board, visual source of truth) [v1.3 | 2026-10-26]; pipeline/place-order/00-request.md |

[v1.4 | 2026-10-27] This specification is split into parts of at most 200 lines each (project file size rule). This file is the index and keeps the old path, so existing links keep working. Content is unchanged from v1.3. The original section numbers (1 to 12, 5.1 to 5.11, 9.1) are kept as headings inside the parts; other documents cite them as "UI section 5.6", "section 8" and so on, so use the table below to find the part.

| Part | File | Sections |
| ---- | ---- | -------- |
| 1 | [Overview, research, user flow, screen inventory](place-order-ui/01-overview-research-flow.md) | 1, 2, 3, 4 |
| 2 | [S-1 Launch, S-2 Home (and common layout)](place-order-ui/02-screens-s1-s2.md) | 5 (common layout), 5.1, 5.2 |
| 3 | [S-3 Product list, S-4 Cake detail](place-order-ui/03-screens-s3-s4.md) | 5.3, 5.4 |
| 4 | [S-5 Choose cakes, S-6 Date and time](place-order-ui/04-screens-s5-s6.md) | 5.5, 5.6 |
| 5 | [S-7 Recipient, S-8 Review, S-9 Confirmation](place-order-ui/05-screens-s7-s9.md) | 5.7, 5.8, 5.9 |
| 6 | [Shared error and offline patterns, board comparison](place-order-ui/06-patterns-board-comparison.md) | 5.10, 5.11 |
| 7 | [Platform notes, motion and haptics](place-order-ui/07-platform-motion.md) | 6, 7 |
| 8 | [Content and copy keys](place-order-ui/08-copy.md) | 8 |
| 9 | [Accessibility, test identifiers](place-order-ui/09-accessibility-test-ids.md) | 9, 9.1 |
| 9b | [Test identifier deviations of the code](place-order-ui/09b-test-ids-deviations.md) [v1.5 | 2026-10-29] | 9.1 (iOS and Android against the canonical set) |
| 10 | [Traceability, assets](place-order-ui/10-traceability-assets.md) | 10, 11 |
| 11 | [Open questions, change log](place-order-ui/11-questions-changelog.md) | 12 |
| 12 | [Delivery fee as an estimate (S-7, S-8, S-9, copy, ids)](place-order-ui/12-fee-estimate-change.md) [v1.7 | 2026-11-02] | 5.7 to 5.9, 8, 9.1 (change) |

| 13 | [Order tracking by phone: S-10, S-11](place-order-ui/13-order-tracking.md) [v1.9 | 2026-11-02] | 14 (new) |
| 14 | [Order tracking: copy, accessibility, test ids, traceability](place-order-ui/14-order-tracking-copy-a11y.md) [v1.9 | 2026-11-02] | 14 (new) |

Quick finds: copy keys (Vietnamese text) are in part 8; test identifiers (`home.*`, `products.*`, `detail.*`, `state.*`) are in part 9; BQ-x and TQ-x questions are in part 11; the date step (5.6) is in part 4; the full change log is in part 11.

## Change log (index)

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.9 | 2026-11-02 | Customer order tracking approved by the owner: Draft labels dropped (parts 13, 14 at v1.0); entry on home S-2 and S-9 only (no menu); cards show code and cake names with quantities; `T_FINISHED_NOTE_30` removed, `T_OLDER_MAY_HIDDEN` and `T_CAKE_LINE` added; `T_EXPECTED_MAY_MOVE` reworded (no notification promise); S-9 edited in place with `T_FOLLOW_ORDER`. [v1.9 | 2026-11-02] |
| 1.8 | 2026-11-02 | Customer order tracking by phone (S-10, S-11, "Follow this order" on S-9) in new parts 13 and 14. |
| 1.7 | 2026-11-02 | PRD v1.7: delivery fee shown as an estimate with the "told at delivery" notice; no total with fee; new part 12 (copy keys, ids). Parts 5 and 8 carry a pointer. Questions PQ-1 to PQ-3 in part 12. |
| 1.6 | 2026-10-29 | OQ-1 answered: S-7 privacy card (FR-20, AC-30), S-8 reminder link, new copy keys and test ids (parts 5, 8, 9, 10, 11). |
| 1.5 | 2026-10-29 | Slice 2 queries answered: new copy keys, {max} note length, canonical S-5 to S-8 test identifiers (parts 9, 9b), `DETAIL_BTN_ORDER` decision, owner question OQ-1 (part 11). |
| 1.4 | 2026-10-27 | Split into 11 parts under `place-order-ui/` and this index; no change of meaning. The change history of versions 1.0 to 1.3 is in part 11. |
