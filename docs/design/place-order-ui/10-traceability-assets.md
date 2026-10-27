# Place Order UI, part 10: Traceability and assets (sections 10, 11)

[v1.4 | 2026-10-27] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Content unchanged from v1.3; section numbers are the original ones.

## 10. Traceability

FR to screens. "X" means the screen implements or shows the requirement.

| FR | S-1 | S-2 | S-3 | S-4 | S-5 | S-6 | S-7 | S-8 | S-9 | Notes |
| -- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ----- |
| FR-1 | X | | | | | | | | | Logo only, then S-2 |
| FR-2 | | X | X | | | | | | | Name, greeting, Zalo, phone, two buttons; [v1.3 | 2026-10-26] the S-3 bar repeats "Place order" |
| FR-3 | | X | X | X | | | | | | Every active cake (1 to 4), picture, name, description, price; zero-cake Error on S-3, disabled order on S-2, Gone on S-4 [v1.2 | 2026-10-26] |
| FR-4 | | | | X | X | | | | | Order button, quantity 1 |
| FR-5 | | | | | X | | | | | Quantity per active cake; removed-cake message [v1.2 | 2026-10-26] |
| FR-6 | | | | | | X | | | | Date choice; unavailable dates not selectable |
| FR-7 | | | | | | X | | | | Fixed slot list |
| FR-8 | | | | | | | X | | | Name, phone, address, district |
| FR-9 | | | | | | | | X | | Review content |
| FR-10 | | | | | X | X | | X | | Blocking messages; hint on S-5; date check on S-6 |
| FR-11 | | | | | | | | X | X | Confirm then code and message |
| FR-12 | | | | | | | | | X | Zalo and phone buttons |
| FR-13 | | | | | | | X | | | Errors next to fields |
| FR-14 | X | X | X | X | X | X | X | X | X | All text Vietnamese, section 8 |
| FR-15 | | | | | X | X | X | X | | Back and Edit keep data |
| FR-16 | | | | | | | | X | | Confirm inert while sending |
| FR-17 | | | | | | | | X | | Not-sent message, data kept |
| FR-18 | | | | | | | X | X | | Note input, counter, shown on review |
| FR-19 | | X | X | X | X | X | X | X | X | Constraint: no payment text anywhere |

Non-FR items covered: privacy sentence before confirmation (PRD section 8, Privacy) on S-8; accessibility and performance (PRD section 8) in sections 5.8 and 9; AC-29 (no visible sample marker) in the global rules. ACs mapped to screens: AC-1 S-1; AC-2, AC-3 S-2; AC-4 S-3; [v1.2 | 2026-10-26] AC-32 S-3, S-5; AC-33 S-2, S-3, S-5; AC-34 S-5, S-8; AC-5 S-4 and S-5; AC-6 S-5, S-8; AC-7, AC-8, AC-10, AC-24 S-6; AC-9, AC-13, AC-22 S-8; AC-11, AC-12, AC-26 S-7; AC-14, AC-18, AC-19, AC-20 S-8; AC-15, AC-16, AC-17, AC-25 S-9; AC-21 all; AC-27 all.

Every FR is traced. No screen element is without an FR; the PRD items BR-1 to BR-12 appear only through the FRs above. AC-28 (cancellation) has no UI. [v1.1 | 2026-10-25] AC-23 (price kept after change) is covered on S-8 by the re-review on `PRICE_CHANGED` (section 5.8).

## 11. Assets

- Design board [v1.3 | 2026-10-26]: `docs/design/reference/` holds the owner's board (24 screens) as markup and CSS plus pictures of the slice 1 screens. It is the visual source of truth for look, layout and size (through `design-system.md` v1.2); this document stays authoritative for states, behaviour and copy keys, and for anything the PRD or an ADR governs. The earlier "mockups, reference only" private link is superseded by this folder.
- Pictures of the cakes: fake placeholder images supplied with launch data; no real customer data in any asset. No exported images are stored in the repository yet.
- Logo [v1.2 | 2026-10-26]: S-1 must show the logo before the catalog loads and the API has no logo field, so the logo is a bundled asset: iOS asset catalog image set `ShopLogo`, Android drawable `shop_logo` (vector or PNG at 1x to 3x), used on S-1 (Large) and S-2 (Small). Shape and masking come from `LogoMark`. [v1.3 | 2026-10-26] The board draws a mark (rounded log rotated -20 degrees with three slanted ties, line style, design-system 2.7) on S-1, S-2 and the admin sign-in; it is the proposed placeholder artwork and BQ-1 asks the owner whether it is the real logo. The owner supplies the artwork (see open question BQ-1); until then a neutral placeholder mark without text or any word "sample", "demo" or "test" is bundled. Replacing the artwork is an asset swap with no layout change. The shop name stays dynamic text from shop data.
- Icons: native system symbols on iOS and Material Symbols on Android, chosen and weighted to match the board's line icons (design-system 2.7) [v1.3 | 2026-10-26]. [v1.1 | 2026-10-25] The Zalo button uses a generic chat icon (SF Symbol / Material Symbol) with the word "Zalo"; the Zalo logo is not used (ADR-0015).
