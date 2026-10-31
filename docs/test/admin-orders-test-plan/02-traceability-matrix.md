# Admin Orders Test Plan: Traceability Matrix (part 02)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.1). Holds: section 2 Traceability Matrix, AC-1 to AC-48 (PRD v1.5) to test cases, and the FR/BR coverage notes. B = backend ([03](03-cases-backend-auth.md), [04](04-cases-backend-orders.md), [05](05-cases-backend-settings.md)), C = iOS and Android ([06](06-cases-clients-contracts.md)), F = contract fixtures. Old AC-1 to AC-72 no longer exist; the id mapping is in the PRD file `admin-orders/08-deferred-and-id-mapping.md`. [v1.1 | 2026-10-31]

## 2. Traceability Matrix

| AC | FR / BR | Priority | Test cases |
| -- | ------- | -------- | ---------- |
| AC-1 | FR-1, BR-4 | Must | TC-B01, B02, B03, B14, B16, B18, C01, C46 |
| AC-2 | FR-1, BR-4 | Must | TC-B04, B05, B13, B15, B17, C01, C03 |
| AC-3 | FR-1, BR-4 | Must | TC-B06, C01, C02, C49 |
| AC-4 | FR-1, FR-6, BR-4 | Must | TC-B07, B08, B09, B10, B11, B12, B19, C03 |
| AC-5 | FR-2, BR-5 | Must | TC-B20, B21, C04 |
| AC-6 | FR-2 | Must | TC-B22, C05 |
| AC-7 | FR-4 | Must | TC-B23, B24, B25, C06 |
| AC-8 | FR-3, FR-20, BR-1 | Must | TC-B31, B32, B33, B34, B35, B28, C07 |
| AC-9 | FR-5, BR-6, BR-4 | Must | TC-B16, B36, B37, B39, B40, C08 |
| AC-10 | FR-5, BR-6 | Must | TC-B29, B30, B38, C08, C47 |
| AC-11 | FR-6, BR-5 | Must | TC-B26, B27, C09 |
| AC-12 | FR-7, BR-13 | Must | TC-B41, B42, B43, B44 |
| AC-13 | FR-8, BR-14 | Must | TC-B45, B46, B47, B48, C10 |
| AC-14 | FR-9, BR-9 | Must | TC-B49, B50, C11 |
| AC-15 | FR-9, BR-7 | Must | TC-B51, C11 |
| AC-16 | FR-9, BR-9 | Must | TC-B52, B53, C12, C45, C50, F08 |
| AC-17 | FR-13, BR-9 | Must | TC-B54, B55, C13, C51, F01, F08 |
| AC-18 | FR-10 | Must | TC-B56, B57, B58, C14 |
| AC-19 | FR-11, BR-10 | Should | TC-B59, B60, B61, B62, C15 |
| AC-20 | FR-12 | Must | TC-B63, C16, C37 |
| AC-21 | FR-9, BR-9 | Must | TC-B64, B65, C18 |
| AC-22 | FR-9, BR-9 | Must | TC-B66, B67, B68, B72, C17 |
| AC-23 | BR-9 | Must | TC-B69, B70, B71, B72, C19 |
| AC-24 | FR-14 | Must | TC-B73, B74, C20 |
| AC-25 | FR-15 | Must | TC-C20 (dialer and Zalo on a real device) |
| AC-26 | FR-16, BR-3 | Must | TC-B75, C21 |
| AC-27 | FR-17, BR-2 | Must | TC-B76, C21 |
| AC-28 | FR-18, BR-2, BR-8 | Must | TC-B77, B78, B79, B84, C22 |
| AC-29 | FR-19 | Must | TC-B80, B81, B82, B83, C23, C35, C38 |
| AC-30 | G-2 | Must | TC-C24, B75 |
| AC-31 | G-1, FR-26 | Must | TC-C25 |
| AC-32 | FR-21 | Must | TC-B107, B108, B109, B110, C26, C34 |
| AC-33 | FR-21, BR-12 | Must | TC-B111 to B118, C26 |
| AC-34 | FR-21, BR-12 | Must | TC-B119, B120, B121, C26 |
| AC-35 | FR-22, BR-11 | Must | TC-B122, B123, B124, C27 |
| AC-36 | FR-22, BR-11 | Must | TC-B125 to B129, B131, C28, C34 |
| AC-37 | FR-23, BR-11 | Must | TC-B132, B133, C29 |
| AC-38 | FR-23, BR-11 | Must | TC-B134, B135, B136, C29 |
| AC-39 | FR-24, BR-11 | Must | TC-B137, B138, C29, C34 |
| AC-40 | BR-11 | Must | TC-B130, B139 to B143, C28 |
| AC-41 | BR-11 | Must | TC-B144 |
| AC-42 | FR-25, G-1 | Must | TC-B88, B93, B94, B95, C31 |
| AC-43 | FR-26 | Must | TC-B89, B90, C31, C39, C40, F06 |
| AC-44 | FR-25, BR-7 | Must | TC-B91, B92, C32, C43 |
| AC-45 | BR-7 | Must | TC-B96, B97, C32 |
| AC-46 | FR-27, BR-8 | Must | TC-B98 to B104, C33, F07 |
| AC-47 | BR-3 | Must | TC-B85, B86, B87, B145 |
| AC-48 | FR-20 | Must | TC-C07, C30 |

## Coverage notes

- All 48 ACs and all 27 FRs have at least one case (checked FR by FR against the FR column of the PRD ACs). FR-6 is covered by AC-4 and AC-11; FR-12 by AC-20; FR-15 by AC-25 (Should in spirit, Must in PRD). [v1.1 | 2026-10-31]
- BR without a dedicated AC, covered by extra cases: BR-1 last sentence (no edit or delete of an order, no payment data) TC-B35; BR-4 address format and length TC-B16; BR-5 grace boundary TC-B27; BR-7 logs and analytics TC-B96, B97; BR-8 first reason kept TC-B103; BR-9 boundaries TC-B53, B65, B72; BR-13 mail content TC-B43; BR-14 isolation TC-B47, B48.
- New rules with strong negative cases: no address lock (TC-B07, B09, B11), four reasons only and removed value `day_full` refused (TC-B78), `fake_spam` is the only reason that counts toward 5 per phone (TC-B98 to B104), notice to the owner address only (TC-B41, B44).
- Deferred features (backup e-mail, two-code recovery, device list and revoke, Unfinished view/chip/banner, status history, multi-filter, push settings, reminder push): no positive cases; negative checks that they are absent are TC-B57, B87, B95, C14, C48.
- G-1 and G-2 now have ACs (AC-31, AC-30): TC-C25, C24. NFR items: performance TC-B105, B106; accessibility TC-C36; privacy TC-B96, TC-C32; Vietnamese format TC-C41; parity is checked in every TC-C case.
- Should ACs: 1 (AC-19); the other 47 are Must. The verdict needs all Must ACs to Pass.
