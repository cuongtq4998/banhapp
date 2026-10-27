# Place Order UI, part 2: Screen specs S-1 Launch and S-2 Home (sections 5, 5.1, 5.2)

[v1.4 | 2026-10-27] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Content unchanged from v1.3; section numbers are the original ones.

## 5. Screen Specs

Common layout (all screens): `AppBackground` behind everything (gradient plus three blurred blobs, design-system 2.1). [v1.3 | 2026-10-26] `TopBar` is the board's custom header: a round glass back button (44 pt iOS, 48 dp Android) at the top left, and below it the large screen title; S-1, S-2 and S-9 have none, S-4 has only the back button floating over the picture. Content scrolls vertically in `GlassCard` groups with `space.cardGap` between groups and `space.screenMargin` side margins (16 pt iOS, 12 dp Android; headings use `space.textMargin`, 24 pt / 16 dp). `BottomActionBar` floats above the bottom edge on S-3, S-4, S-5, S-6, S-7, S-8 and S-9 (S-2 has the contact buttons in that place instead, section 5.2); content has bottom padding equal to the bar height so nothing is hidden. In S-5 to S-8 the `StepIndicator` sits to the right of the back button (the board shows the back button and the step capsule on one line, the title below).

### 5.1 S-1 Launch

- Purpose: show the brand while the app starts (FR-1).
- Entry/Exit: entry on app start. Exit to S-2 automatically after the start work finishes, shown for at least 1.0 s and at most 2.0 s (proposed values, adjustable). Nothing is tappable.
- Layout: `AppBackground`; `LogoMark` (Large) centred in the screen, no text, no button, no loading text. [v1.3 | 2026-10-26] Board sizes: iOS glass rounded square 132 pt, corner 40 pt, mark 76 pt, `color.primary`; Android blob 168 dp filled `color.primaryContainer` with a 1 dp white-70% edge and a soft shadow, mark 96 dp. The board's launching screen is a link to Home (a prototype device); in the app nothing is tappable and the exit stays automatic.
- Data shown: the logo only (FR-1). [v1.2 | 2026-10-26] The logo is a bundled app asset (iOS asset catalog image set, Android drawable), shown before any network call; the API has no logo field. Until the owner supplies the artwork, a neutral placeholder mark with no text is bundled (section 11). `LogoMark` on S-2 uses the same asset.
- Actions: none.
- States:

| State | Behaviour |
| ----- | --------- |
| Default | Logo centred with a gentle scale-in (`motion.duration.long`). |
| Loading | Same as Default. Any start work happens behind the logo; no spinner is shown. |
| Empty | N/A: the screen shows no data. |
| Error | N/A: start never blocks here; data load failures are shown on S-2 (section 5.2). |
| Disabled | N/A: no controls. |
| Success | N/A: exit to S-2 is the only outcome. |

- Validation: none.
- Accessibility: the logo has the label `LOGO_LABEL`; the screen is announced once.

### 5.2 S-2 Home

- Purpose: entry point (FR-2).
- Entry/Exit: from S-1 and from S-9. Exits to S-3 (View products), S-5 (Place order), the Zalo app or the phone dialer.
- Layout, top to bottom [v1.3 | 2026-10-26] (follows the board; wireframe below): `LogoMark` (Small: 72 pt glass square on iOS, 88 dp blob on Android) centred; shop name centred in `type.display` (30 pt / 32 sp); greeting centred in `type.body`, `color.text.secondary`, at most 280 pt / 290 dp wide, plain text on the background (no card); two `HeroActionCard` stacked with `space.cardGap`: first "View products" (glass, `HOME_BTN_PRODUCTS`, subtitle `HOME_PRODUCTS_SUB`), then "Place order" (primary fill, `HOME_BTN_ORDER`, subtitle `HOME_ORDER_SUB`), each with a trailing chevron (Android: inside a 52 dp round badge); at the bottom edge, in place of a bar, two equal `ContactButton` capsules side by side (Zalo, Phone) with `space.barInset` margins. [v1.1 | 2026-10-25] The Zalo button shows a generic chat icon plus the word "Zalo", never the Zalo brand mark (ADR-0015); [v1.3 | 2026-10-26] the board adds the shop's Zalo number after the word and shows the shop's phone number as the phone button text.
- Data shown: shop name, short greeting (both from shop data, no marker), the Zalo and phone numbers (shop data), the count of active cakes for `HOME_PRODUCTS_SUB` (hidden while no product answer exists, hidden at zero; see BQ-4).

```
iOS 390 x 844                         Android 412 x 892
+--------------------------+          +----------------------------+
|        [glass logo 72]   |          |       [blob logo 88]       |
|    {shop name, 30 pt}    |          |    {shop name, 32 sp}      |
|    {greeting, 15 pt}     |          |    {greeting, 16 sp}       |
|                          |          |                            |
| +----------------------+ |          | +------------------------+ |
| | Xem sản phẩm       > | | 132 pt   | | Xem sản phẩm        (>)| | 140 dp
| | {n} loại bánh tét    | |  glass   | | {n} loại bánh tét      | |  glass
| +----------------------+ |          | +------------------------+ |
| +----------------------+ |          | +------------------------+ |
| | Đặt bánh           > | | 132 pt   | | Đặt bánh            (>)| | 140 dp
| | Chọn bánh, ngày giờ..| |  primary | | Chọn bánh, ngày giờ... | |  primary
| +----------------------+ |          | +------------------------+ |
|                          |          |                            |
| [Zalo {number}] [{phone}]|  56 pt   | [Zalo {number}] [{phone}]  | 60 dp
+--------------------------+          +----------------------------+
 x positions: cards 16 pt from the sides   cards 12 dp from the sides, top 296 dp
 top of cards 290 pt; contacts 28 pt from  asymmetric corners (44 dp, one 16 dp)
 the bottom edge
```

Measured values from the board (iOS / Android): logo block top padding 76 pt / 72 dp; gap logo to name 14 / 12; cards start 290 pt / 296 dp from the top; card padding 24 pt / 28 dp; contact capsules 10 pt apart.
- Actions:

| Action | Result | FR |
| ------ | ------ | -- |
| Tap Zalo | Opens Zalo with the shop contact (AC-3). If it cannot open, `Toast` with `ERR_OPEN_ZALO`. | FR-2 |
| Tap Phone | Opens the dialer with the shop number (AC-3). If it cannot open, `Toast` with `ERR_OPEN_PHONE`. | FR-2 |
| Tap View products | Go to S-3. | FR-2, FR-3 |
| Tap Place order | [v1.1 | 2026-10-25] If a saved draft exists, go to S-5 with the restored data and no prompt. Otherwise go to S-5 with no cake chosen. [v1.2 | 2026-10-26] The button is disabled while the known active-cake count is zero (below), so no flow starts (AC-33). | FR-2, FR-15 |

- States:

| State | Behaviour |
| ----- | --------- |
| Default | All six elements visible. [v1.3 | 2026-10-26] `HOME_PRODUCTS_SUB` is shown only when the number of active cakes is known and at least 1 (for example "4 loại bánh tét"); it is never typed into the layout. |
| Loading | Only when there is no cache: skeleton for name and greeting (`StateView` Loading); contact and order buttons visible but disabled. [v1.3 | 2026-10-26] The two action cards show their titles with no subtitle. |
| Empty | N/A: shop information is required data; a missing value is treated as Error. |
| Error | [v1.1 | 2026-10-25] Shown only when shop information could not be loaded and there is no cache (cache is valid up to 7 days, ADR-0011): `StateView` Error with `HOME_ERR` and `COMMON_RETRY`; all four action buttons disabled. When a cache exists, the cached data is shown at once (Default), refreshed in the background, and a failed refresh is silent. |
| Disabled | Contact buttons are disabled while Loading and Error. The "Place order" and "View products" buttons follow the same rule. |
| No cakes (sub-state of Default) [v1.2 | 2026-10-26] | Shown when the latest product answer has zero active cakes (BR-13, AC-33). Shop name, greeting and contact buttons work as in Default. The "Place order" `HeroActionCard` is disabled (dimmed to the disabled style of design-system 2.8, still announced with its text and state "dimmed"; [v1.3 | 2026-10-26] the title stays and the subtitle is hidden). An `InlineMessage` (Info) `HOME_NO_CAKES` sits between the "Place order" card and the contact capsules (the greeting is plain text on this screen, so there is no greeting card to place it under). "View products" stays enabled and opens S-3, which shows its zero-cake Error state. The state ends as soon as a later answer has at least one active cake (refresh on screen appear and on returning to the foreground; no app reinstall, AC-33): the message disappears and the button is enabled. With no product answer yet (first launch, still loading) Place order is enabled; S-5 then handles zero (section 5.5). |
| Success | N/A: no submit on this screen. |

- Validation: none.
