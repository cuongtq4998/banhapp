# Admin Orders Test Plan: Traceability Matrix (part 02)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.0). Holds: section 2 Traceability Matrix, AC-1 to AC-72 to test cases, and the FR/BR coverage notes. B = backend ([03](03-cases-backend-auth.md), [04](04-cases-backend-orders.md), [05](05-cases-backend-settings.md)), C = iOS and Android ([06](06-cases-clients-contracts.md)), F = contract fixtures. [v1.0 | 2026-10-31]

## 2. Traceability Matrix

| AC | FR | Priority | Test cases |
| -- | -- | -------- | ---------- |
| AC-1 | FR-1 | Must | TC-B01, B19, C01 |
| AC-2 | FR-1 | Must | TC-B02, B03, B13, C01 |
| AC-3 | FR-2 | Must | TC-B04, C01 |
| AC-4 | FR-2 | Must | TC-B05, B06, C03 |
| AC-5 | FR-2 | Must | TC-B07, C03 |
| AC-6 | FR-3 | Must | TC-B08, B12, C02 |
| AC-7 | FR-3 | Must | TC-C01 |
| AC-8 | FR-6 | Must | TC-B09, B10, B14, B15, C03 |
| AC-9 | FR-6 | Must | TC-B11, B22, C03 |
| AC-10 | FR-4 | Must | TC-B23, B24, C04 |
| AC-11 | FR-4 | Must | TC-B25, C04 |
| AC-12 | FR-5 | Must | TC-B39, B40 |
| AC-13 | FR-5 | Must | TC-B37, B38 |
| AC-14 | FR-7 | Must | TC-B30, C05 |
| AC-15 | FR-8 | Must | TC-B53, C07 |
| AC-16 | FR-8 | Must | TC-B54, C07 |
| AC-17 | FR-9 | Must | TC-B55, C08 |
| AC-18 | FR-10 | Must | TC-B56, B57, C08, C45 |
| AC-19 | FR-11 | Should | TC-B58, B59, C09 |
| AC-20 | FR-12 | Must | TC-B60, C10 |
| AC-21 | FR-12 | Must | TC-C10 |
| AC-22 | FR-13 | Must | TC-C11, F01 |
| AC-23 | FR-8 (BR-13) | Must | TC-B61, B62, B63, C12 |
| AC-24 | FR-14 | Must | TC-B64, C13 |
| AC-25 | FR-15 | Should | TC-C13 (real device for dialer and Zalo) |
| AC-26 | FR-16 | Must | TC-B65, C14 |
| AC-27 | FR-17 | Must | TC-B66, C14 |
| AC-28 | FR-18 | Must | TC-B67, B75 |
| AC-29 | FR-18 | Must | TC-B68, B69, C15 |
| AC-30 | FR-19 | Must | TC-B70, B71, B72, B73, C16 |
| AC-31 | FR-20 | Should | TC-B76, B77, B78, C17 |
| AC-32 | FR-21 | Must | TC-C18, B39 |
| AC-33 | FR-22 | Must | TC-B101, B102, C19 |
| AC-34 | FR-22 | Must | TC-B103, B104, C19 |
| AC-35 | FR-23 | Must | TC-B105 |
| AC-36 | FR-23 | Must | TC-B106, C20 |
| AC-37 | FR-24 | Must | TC-B107 |
| AC-38 | FR-24 | Must | TC-B108, B109, B110, C21 |
| AC-39 | FR-25 | Must | TC-B111 |
| AC-40 | FR-25 | Must | TC-B112, B113, C20 |
| AC-41 | FR-26 | Must | TC-B114, B115, C20 |
| AC-42 | FR-27 | Must | TC-B116, C22 |
| AC-43 | FR-27 | Must | TC-B117, B118, C22 |
| AC-44 | FR-27 | Must | TC-B119, B34 |
| AC-45 | FR-28 | Must | TC-B120, B121, C20 |
| AC-46 | FR-29 | Must | TC-B122 |
| AC-47 | FR-30 | Should | TC-B123, B124 |
| AC-48 | FR-31 | Must | TC-B85, C23 (real push Blocked) |
| AC-49 | FR-32 | Must | TC-B86, C24, F06 |
| AC-50 | FR-33 | Should | TC-B87, C23, C38 |
| AC-51 | FR-34 | Should | TC-C24, C44 |
| AC-52 | FR-35 | Must | TC-B88, B89, C25 |
| AC-53 | FR-36 | Must | TC-B26 |
| AC-54 | FR-36 | Must | TC-B27, B28, C06 |
| AC-55 | FR-37 | Must | TC-B31, B35, C05 |
| AC-56 | FR-37 | Must | TC-B32, B33, B36, C26 |
| AC-57 | FR-42 | Must | TC-B42, B43, B51, C27 |
| AC-58 | FR-43 | Must | TC-B44, B49, B50, C27 |
| AC-59 | FR-43 | Must | TC-B45, B46, B47, B48, C27 |
| AC-60 | FR-38 | Must | TC-B125, C28 |
| AC-61 | FR-38 | Must | TC-B126, B127, B128, B129, C28 |
| AC-62 | FR-39 | Must | TC-B131, B134, C28 |
| AC-63 | FR-39 | Must | TC-B132, B133, C28 |
| AC-64 | FR-40 | Must | TC-B135, C29 |
| AC-65 | FR-40 | Must | TC-B136, C29 |
| AC-66 | FR-40, FR-28 | Must | TC-B137, B138 |
| AC-67 | FR-41 | Must | TC-B80, B84, C30 |
| AC-68 | FR-41 | Must | TC-B81, C30 |
| AC-69 | FR-18 | Must | TC-B69, C15 |
| AC-70 | FR-44 | Must | TC-B93 |
| AC-71 | FR-44 | Must | TC-B94 |
| AC-72 | FR-44 | Must | TC-B95, B96, B97, B98 |

## Coverage notes

- All 72 ACs and all 44 FRs have at least one case (checked FR by FR against the "FR" column of the PRD ACs). [v1.0 | 2026-10-31]
- BR without a dedicated AC, covered by extra cases: BR-1 last sentence (no edit or delete of an order, no payment data) TC-B41; BR-4 immutability TC-B77; BR-7 normalisation TC-B19, TC-B51; BR-8 deactivate the owner TC-B117; BR-13 secondary sort for Completed and Cancelled TC-B53; BR-15 logs and sign-out data TC-B92, TC-C25; BR-18 12-cake limit TC-B127; BR-20 boundary TC-B82.
- G-1 "open in at most 2 taps from the notification" and G-2 "1 action and at most 1 confirmation step" have no AC; they are covered by TC-C23 and TC-C15 as step counts (see finding R-9 in [08](08-review-findings.md)).
- NFR items: performance TC-B99; accessibility TC-C32; privacy TC-B92, TC-C25, TC-C42; Vietnamese format TC-C39; Android and iOS parity is checked in every TC-C case.
- Should ACs: 6 (AC-19, 25, 31, 47, 50, 51); the other 66 are Must. The verdict needs all Must ACs to Pass.
