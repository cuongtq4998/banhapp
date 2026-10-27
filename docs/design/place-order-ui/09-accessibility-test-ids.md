# Place Order UI, part 9: Accessibility and test identifiers (sections 9, 9.1)

[v1.4 | 2026-10-27] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Content unchanged from v1.3; section numbers are the original ones.

## 9. Accessibility

Defaults from standard 02 apply: touch target at least 44 pt (iOS) and 48 dp (Android); contrast at least 4.5:1; every icon-only control labelled; layout survives the largest text size. Details:

| Topic | Specification |
| ----- | ------------- |
| Labels | Back (`COMMON_BACK`), steppers (`QTY_INC_A11Y`, `QTY_DEC_A11Y`, value `QTY_VALUE_A11Y`), contact buttons (their visible text), month controls (month name spoken), product image (cake name, or `PRODUCT_IMG_FAILED`), order code (`CONF_CODE_A11Y`, read character by character). |
| Calendar | Each day is one element with a spoken date and state (`DATE_A11Y_*`). Unavailable days are announced as unavailable with the reason. The grid is operable with a screen reader and keyboard or switch navigation. |
| Errors | Field errors are announced when they appear and are linked to the field; focus moves to the first invalid field after a failed Next (AC-12). Banners on S-8 are announced as alerts. |
| Dynamic type | Text scales to the largest iOS accessibility size and 200% Android. Rows wrap to two lines, steppers stack the value below the name if the row is too narrow, the calendar cell grows in height; content scrolls; the bottom bar never covers content (content bottom padding follows the bar height). |
| Contrast | Text on glass uses `color.text.primary` on `color.surface.glass`; if the blob behind lowers contrast below 4.5:1 the surface uses `color.surface.solid`. Primary button text `color.onPrimary` on `color.primary` is about 6.4:1 (estimate; to be measured). |
| Not colour alone | Selected and unavailable dates differ by fill, border and strike pattern, and by spoken state. |
| Motion | Reduce Motion and remove-animation settings turn all movement into 150 ms cross-fades. |
| Focus | Visible focus ring `color.focus` for external keyboards and switch control. |
| Language | The screen reader language for all text is Vietnamese. |
| Zero-cake and gone states [v1.2 | 2026-10-26] | `PRODUCTS_EMPTY`, `HOME_NO_CAKES`, `DETAIL_GONE` and `ORDER_CAKE_REMOVED` are announced as they appear (polite for S-2 and S-4, alert for S-5 after S-8 sends the customer back). The disabled "Place order" button is read with its text and the state "dimmed"; the message above it explains why. |

### 9.1 Test identifiers [v1.2 | 2026-10-26]

One list for both platforms: iOS `accessibilityIdentifier` and Android `Modifier.testTag` use the identical string. Android names come from `android/app/src/main/kotlin/app/banh/customer/TestTags.kt`. UI tests select by identifier only, never by visible text. A tag goes on the element that is tapped or asserted (one element per card or button; on iOS combine children of a card so the card is one element). `<id>` is the cake id from the API.

| Identifier | Element | Screen | In Android file |
| ---------- | ------- | ------ | --------------- |
| `launch.logo` | Logo | S-1 | yes |
| `home.shopName` | Shop name text | S-2 | yes |
| `home.greeting` | Greeting text | S-2 | yes |
| `home.zaloButton` | Zalo button | S-2 | yes |
| `home.phoneButton` | Phone button | S-2 | yes |
| `home.productsButton` | View products button | S-2 | yes |
| `home.orderButton` | Place order button (enabled or disabled) | S-2 | yes |
| `home.skeleton` | Loading skeleton | S-2 | yes |
| `home.noCakesNotice` | `HOME_NO_CAKES` message | S-2 | NO, new |
| `home.productsCount` | [v1.3 | 2026-10-26] `HOME_PRODUCTS_SUB` subtitle on the "View products" card (absent while the count is unknown or zero) | S-2 | NO, new |
| `nav.back` | [v1.3 | 2026-10-26] Round glass back button of the custom header (same identifier on every screen that has one; tests tell screens apart by the other identifiers on screen) | S-3, S-4, S-5 to S-8 | NO, new |
| `products.orderButton` | [v1.3 | 2026-10-26] `HOME_BTN_ORDER` button in the S-3 bottom bar (enabled or disabled) | S-3 | NO, new |
| `products.list` | Scrolling list container | S-3 | yes |
| `products.card.<id>` | One cake card | S-3 | yes (function `productCard`) |
| `products.skeleton.<index>` | Skeleton card, index from 0 | S-3 | yes (function `productCardSkeleton`) |
| `detail.name` | Cake name | S-4 | yes |
| `detail.description` | Description | S-4 | yes |
| `detail.price` | Price | S-4 | yes |
| `detail.orderButton` | Order this cake button | S-4 | yes |
| `detail.imageFailed` | Image failure placeholder | S-3 card and S-4 (`products.card.<id>` keeps its own id; this tag is inside it) | NO, new |
| `detail.goneNotice` | `DETAIL_GONE` message | S-4 | NO, new |
| `detail.goneAction` | `DETAIL_GONE_ACTION` button | S-4 | NO, new |
| `order.step` | Step label of the S-5 stub (and S-5 in the full flow) | S-5 | yes (`ORDER_STUB_STEP`) |
| `order.cakeRemovedNotice` | `ORDER_CAKE_REMOVED` message | S-5 | NO, new (full S-5 only, not in the stub) |
| `state.error` | Error `StateView` of any screen (load failure) | S-2 to S-5 | yes |
| `state.retry` | Retry button inside `state.error` or `state.empty` | any | yes |
| `state.empty` | Zero-cake `StateView` (`PRODUCTS_EMPTY`) | S-3, S-5 | NO, new |

[v1.3 | 2026-10-26] `home.productsButton` and `home.orderButton` now sit on the two large home action cards (the whole card is the element; the title and subtitle are its children, so the card is one element). `home.zaloButton` and `home.phoneButton` sit on the two contact capsules at the bottom edge of S-2.

Differences for forge-dev: the Android file lacks `home.noCakesNotice`, `home.productsCount`, `nav.back`, `products.orderButton`, `detail.imageFailed`, `detail.goneNotice`, `detail.goneAction`, `order.cakeRemovedNotice` and `state.empty` (add them with the zero-cake work and the board alignment). `state.retry` is shared by the Error and Empty states. The iOS app has no identifiers yet (the only UI test finds the text "Banh App": replace it). Full S-5 to S-9 identifiers will be published with their own stage.

States each UI test must reach (both platforms, with the fake API or fixture):

| Screen | States to reach |
| ------ | --------------- |
| S-1 | Default (`launch.logo` visible, then S-2 appears). |
| S-2 | Default (with `home.productsCount` showing the active count, [v1.3 | 2026-10-26]); Loading without cache (`home.skeleton`); Error without cache (`state.error`, `state.retry`, all four buttons disabled); No cakes (`home.noCakesNotice` visible, `home.orderButton` disabled, `home.productsButton` enabled, `home.productsCount` absent, then back to Default after a cake becomes active). |
| S-3 | Default with 4, 3, 2 and 1 cards (`products.card.<id>` count equals the active cakes, no extra card; `products.orderButton` enabled [v1.3 | 2026-10-26]); Loading (`products.skeleton.0`); Error without cache (`state.error`); zero cakes (`state.empty`, no `products.list` cards, `products.orderButton` disabled, `state.retry` then a cake becomes active and its card appears); image failure (`detail.imageFailed`, card still tappable); `nav.back` returns to S-2. |
| S-4 | Default (name, description, price, order button, `nav.back`); Gone (`detail.goneNotice`, `detail.goneAction`, no `detail.orderButton`); image failure. |
| S-5 stub | `order.step` visible after tapping `home.orderButton` and after tapping `detail.orderButton`. |
