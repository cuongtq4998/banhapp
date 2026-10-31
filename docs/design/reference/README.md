# Design reference (owner's original design)

| Field        | Value |
| ------------ | ----- |
| Version      | 1.0 |
| Last updated | 2026-10-26 |
| Status       | Draft |
| Owner        | canvas-ui |
| Source       | Design board supplied by the product owner (HTML prototype, 24 screens) |

The running apps do not look like this design. This folder is the **visual source of truth** for how the screens must look; `docs/design/place-order-ui.md` (states, copy, behaviour) must agree with it, and where they differ the design board wins until the owner says otherwise.

## Files

| File | Content |
| ---- | ------- |
| `dat-banh-tet-ios-android.html` | The original board, unchanged. Open it in a browser. 12 iOS screens at 390 x 844 and 12 Android screens at 412 x 892. It embeds Be Vietnam Pro and Roboto Flex font files; keep the licence comment at the top of the file (SIL Open Font License 1.1) if it is passed on. |
| `renders/*.png` | Pictures of the slice 1 screens (launching, home, products, cake detail; iOS 390 x 844, Android 412 x 892) rendered from the board with headless Chrome on 2026-10-26, for quick comparison with screenshots of the running apps. |
| `screens/*.html` | The same 24 screens as separate pages, with the embedded font data replaced by the text `<EMBEDDED-FONT-DATA-REMOVED>` so that people and agents can read the markup and CSS (colours, sizes, spacing, radii). Fonts: Be Vietnam Pro, Roboto Flex. |

## Screens

| Order | Screen | iOS file | Android file | Slice |
| ----- | ------ | -------- | ------------ | ----- |
| 0 | Launching | `ios-00-launching` | `android-00-launching` | 1 |
| 1 | Home | `ios-01-home` | `android-01-home` | 1 |
| 2 | Products | `ios-02-products` | `android-02-products` | 1 |
| 3 | Cake detail | `ios-03-cake-detail` | `android-03-cake-detail` | 1 |
| 4 | Choose cakes | `ios-04-choose-cakes` | `android-04-choose-cakes` | 2 |
| 5 | Delivery | `ios-05-delivery` | `android-05-delivery` | 2 |
| 6 | Review order | `ios-06-review` | `android-06-review` | 2 and 3 |
| 7 | Order placed | `ios-07-success` | `android-07-success` | 4 |
| A1 to A4 | Admin: sign in, orders, order detail, settings | `ios-a1-...` to `ios-a4-...` | `android-a1-...` to `android-a4-...` | Later slices (staff and owner features are outside the first slice) |

## Rules

- The board is a design, not data: it holds no real customer, phone number, address or account (checked 2026-10-26: no e-mail, phone or key in the text).
- Sample names and numbers on the board are placeholders; customer-visible text in the apps follows the copy table of `place-order-ui.md` and the "no sample marker" rule (PRD AC-29).

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-26 | Board and split screens added from the owner's file. |
