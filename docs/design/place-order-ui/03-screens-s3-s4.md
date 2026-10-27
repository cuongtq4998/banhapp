# Place Order UI, part 3: Screen specs S-3 Product list and S-4 Cake detail (sections 5.3, 5.4)

[v1.4 | 2026-10-27] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Content unchanged from v1.3; section numbers are the original ones.

### 5.3 S-3 Product list

- Purpose: show every active cake (FR-3, BR-13). [v1.2 | 2026-10-26]
- Entry/Exit: from S-2. Exit to S-4 (tap a card), to S-5 (bar button, [v1.3 | 2026-10-26]) or back to S-2.
- Layout: `TopBar` (back button, then large title `PRODUCTS_TITLE` below it, `type.title.large`) [v1.3 | 2026-10-26]; one `ProductCard` per active cake in a single-column vertical list, in the order the API returns. [v1.3 | 2026-10-26] Each card (board): thumbnail 84 pt / 84 dp at the left, then name, a two-line description and the price, and a trailing chevron (a bare chevron on iOS; inside a 40 dp round `color.primaryContainer` badge on Android); card gap `space.cardGap` (12), card padding 12. [v1.2 | 2026-10-26] 1, 2, 3 and 4 cards are all normal and use the same card size and spacing (`space.lg`); the list is simply shorter. There is no placeholder, empty slot, "coming soon" card, gap or reserved space for a hidden cake, and no text saying fewer cakes are shown. The list never needs to scroll for 1 to 3 cards on a typical phone; with 4 cards or large text it scrolls. [v1.3 | 2026-10-26] A `BottomActionBar` with a full-width `PrimaryButton` `HOME_BTN_ORDER` floats at the bottom (the board shows it on this screen; the earlier "no bottom bar" rule is removed because neither the PRD nor an ADR forbids a second place to start an order; see BQ-5 for the open confirmation). Tap: same as "Place order" on S-2 (restored draft, or a new draft with no cake chosen, then S-5). It is disabled while the known active-cake count is zero, and in the zero-cake Error state. Content has bottom padding of about 130 pt for the bar.
- Data shown per card: picture, name, short description, current price. Exactly the active cakes returned (AC-4, AC-32). [v1.2 | 2026-10-26]
- Actions: tap a card to open S-4 (FR-3, FR-4); [v1.3 | 2026-10-26] tap the bar button `HOME_BTN_ORDER` to start an order as on S-2 (FR-2 entry rules, FR-15).
- Wireframes [v1.2 | 2026-10-26]: the structure does not change with rotation (single column, cards fill the width inside `space.screenMargin`; in landscape the cards are wider and the list scrolls), so the wireframes are by card count at compact width, as the design process allows. `[card]` = picture, name, description, price.

```
 1 cake          2 cakes         3 cakes         4 cakes         0 cakes (Error)
+-----------+   +-----------+   +-----------+   +-----------+   +-----------+
| < Sản phẩm|   | < Sản phẩm|   | < Sản phẩm|   | < Sản phẩm|   | < Sản phẩm|
| [card A ] |   | [card A ] |   | [card A ] |   | [card A ] |   |           |
|           |   | [card B ] |   | [card B ] |   | [card B ] |   |   (icon)  |
|  (blank   |   |           |   | [card C ] |   | [card C ] |   | PRODUCTS_ |
|  background)  |  (blank)  |   |           |   | [card D ] |   |   EMPTY   |
|           |   |           |   |  (blank)  |   | (scrolls) |   | [Thử lại] |
+-----------+   +-----------+   +-----------+   +-----------+   +-----------+
```

[v1.3 | 2026-10-26] In every variant the floating bar with `HOME_BTN_ORDER` sits at the bottom edge (not drawn above); the back button and title sit at the top. Landscape: the same single column with wider cards; with 1 or 2 cards the content stays at the top and the rest is background; the Error state is centred. No two-column variant is used, so a count of 3 never leaves an orphan cell.
- States:

| State | Behaviour |
| ----- | --------- |
| Default | One `ProductCard` per active cake (1 to 4). |
| Loading | [v1.1 | 2026-10-25] Only when there is no cache: four skeleton cards (`StateView` Loading). With a cache, cached cards show at once. [v1.2 | 2026-10-26] The skeleton count is a visual placeholder only and disappears when the answer arrives; it never implies four cakes. |
| Empty | [v1.2 | 2026-10-26] Zero active cakes (a successful answer with an empty list): `StateView` Error layout with an icon, `PRODUCTS_EMPTY` (Vietnamese text in section 8) and the action `COMMON_RETRY` (reloads the list; the shop may have made a cake active again, AC-33). No list, no placeholder cards. This is the only count-based Error (BR-13). A cached non-empty list is replaced by the zero answer when a fresh answer says zero. |
| Error | [v1.1 | 2026-10-25] Only when there is no cache: `StateView` Error with `PRODUCTS_ERR` and `COMMON_RETRY` (load failure, different from the zero-cake state). With a cache, a failed refresh is silent. A single failed picture shows a placeholder icon in the image frame (label `PRODUCT_IMG_FAILED`) while the card stays tappable. |
| Disabled | Cards are always tappable once shown. [v1.3 | 2026-10-26] The bar button is disabled while the known active-cake count is zero (Empty state) and while Loading without cache. |
| Success | N/A: no submit. |

- Validation: none.

### 5.4 S-4 Cake detail

- Purpose: show one cake and start an order with it (FR-4).
- Entry/Exit: from S-3. Exit to S-5 (order button) or back to S-3 (back button; accessibility label `BACK_TO_LIST`).
- Cake no longer available [v1.2 | 2026-10-26]: if the shop hides this cake while S-4 is open, the screen learns it on its background refresh, on returning to the foreground, or when `DETAIL_BTN_ORDER` is tapped (the tap rechecks the active list first). The screen then shows the Gone state below instead of starting an order.
- Layout [v1.3 | 2026-10-26] (follows the board): no title bar. A large hero picture at the top with the round glass back button floating over its top left corner (iOS: picture inset 16 pt from the sides, 56 pt from the top, 330 pt high, corner 36 pt; Android: picture full width from the top edge, 400 dp high, bottom corners 56 dp). Overlapping or just below the picture, a `GlassCard` (iOS top at 406 pt, 16 pt margins, padding 20 pt, corner 32 pt; Android top at 352 dp so it overlaps the picture by 48 dp, 12 dp margins, padding 22 dp, corner 40 dp) holds, top to bottom: cake name (`type.title.detail`), price (`type.price.detail`, with `PRICE_EACH`), description (`type.body`, `color.text.secondary`). `BottomActionBar` with `PrimaryButton` `DETAIL_BTN_ORDER`. The card order changed from "name, description, price" to "name, price, description".
- Data shown: picture, name, description, current price. [v1.3 | 2026-10-26] The board also shows two chips under the description ("[Trọng lượng]" and "[Hạn dùng]", weight and shelf life). The PRD has no such attributes and the API has no such fields, so the chips are not specified or built; see BQ-3. If the owner confirms them, `InfoChip` (design-system 3) is used.
- Actions: tap `DETAIL_BTN_ORDER` opens S-5 with this cake at quantity 1, other cakes at 0 (AC-5).
- States:

| State | Behaviour |
| ----- | --------- |
| Default | As above. |
| Loading | [v1.2 | 2026-10-26] N/A: S-4 is opened only from a card on S-3 (or in the same session), so the cake data is already in hand and shown at once. S-4 is never restored after the system ends the app (ADR-0011 restores only the draft, to S-5; the app then starts at S-1), so there is no restore path to S-4. The earlier skeleton and "after a restore" wording was wrong and is removed (QA DOC-9). |
| Empty | N/A: a detail is reached only from an existing card. |
| Gone [v1.2 | 2026-10-26] | The cake is no longer in the active list. The picture and text stay visible but dimmed; an `InlineMessage` (Info) `DETAIL_GONE` is shown above the card; `BottomActionBar` shows `SecondaryButton` `DETAIL_GONE_ACTION` that returns to S-3 (the refreshed list, which may now have fewer cards or the zero-cake Error state); the order button is not shown. Nothing was added to a draft. |
| Error | Picture failed: placeholder and `PRODUCT_IMG_FAILED`, button still enabled. [v1.2 | 2026-10-26] A failed background refresh is silent (the cake data came from the list); no data-failed Error exists on this screen. |
| Disabled | [v1.2 | 2026-10-26] N/A: the order button is enabled in Default and replaced by the Gone action in Gone. |
| Success | N/A: no submit. |

- Validation: none.
