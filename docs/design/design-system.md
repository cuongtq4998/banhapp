# Design System

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.2 [v1.2 | 2026-10-26]                                                |
| Last updated | 2026-10-26                                                            |
| Status       | Draft                                                                 |
| Owner        | canvas-ui                                                             |
| Based on     | product/place-order.md v1.4 (first consumer); design/reference (owner's design board, visual source of truth) [v1.2 | 2026-10-26] |
| Related      | design/place-order-ui.md; design/reference/README.md                  |

## 1. Principles

1. Native feel first. iOS follows Liquid Glass; Android follows Material 3 Expressive. One component name, two native renderings.
2. Glass and blur are used for navigation and action layers (bars, cards over the background), not for long text blocks. Text sits on surfaces that keep contrast of at least 4.5:1.
3. Every glass or blur surface has a documented fallback (older OS, Reduce Transparency, no blur support).
4. Whole-dong money. Amounts are shown as whole VND with a dot as thousands separator and the dong sign, for example `125.000 ₫` (sample number). No decimals.
5. Vietnamese text needs full diacritic support and extra line height; no component clips text at the largest text size.
6. Tokens carry semantic names. Feature documents use token names only.
7. [v1.2 | 2026-10-26] The owner's design board (`docs/design/reference/`) is the visual source of truth. The values in section 2 were extracted from its CSS; where the board and an earlier version of this document differed, the board won. "Board" below always means that folder. Sample names, numbers and bracketed placeholders on the board (for example `[Tên tiệm]`, `[Giá]`) are design placeholders; the apps show shop data as received.

### Sources and confidence

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| `GlassEffectContainer` merges several Liquid Glass shapes so they render together and can morph; used with `glassEffect(_:in:)`; available from iOS 26 | https://developer.apple.com/documentation/swiftui/glasseffectcontainer.md | 2026-10-25 | High (Apple documentation) |
| Variants `.regular`, `.clear`, `.interactive()`; button styles `.glass` and `.glassProminent`; `glassEffectID` morphing; glass should not sample other glass | Community guides, e.g. https://levelup.gitconnected.com/swiftui-liquid-glass-from-basic-to-a-little-advance-cdef4e4c5b90 and https://medium.com/@veersr9/ios-26-liquid-glass-in-swiftui-a-practical-reference-demo-app-liquidglassreference-69b8d46dc055 | 2026-10-25 | Medium (secondary; verify against Apple docs before build) |
| Liquid Glass automatically adapts to Reduce Transparency and Increase Contrast | Apple Human Interface Guidelines, Materials / Liquid Glass (not fetched) | 2026-10-25 | Unverified |
| Fallback for iOS before 26: SwiftUI `Material` backgrounds (`.ultraThinMaterial` or `.regularMaterial`) with a hairline stroke | Apple SwiftUI `Material` documentation (not fetched) | 2026-10-25 | Unverified |
| Material 3 Expressive components in Compose Material3: `LoadingIndicator`, `ButtonGroup`, `SplitButtonLayout`, `FloatingToolbar`, `FlexibleBottomAppBar`, `FloatingActionButtonMenu`, `MaterialExpressiveTheme`; seen in 1.4.0 alpha builds, some experimental | https://proandroiddev.com/material-3-expressive-design-a-new-era-9ea77959a262 and https://proandroiddev.com/material-3-expressive-design-a-new-era-part-2-6a93483c98b0 | 2026-10-25 | Medium (third-party articles; official Material 3 pages could not be read) |
| Material 3 Expressive stable status, spring-based motion scheme, shape morphing and the exact API names in the current Compose release | https://m3.material.io/blog/building-with-m3-expressive (page returned no readable content) | 2026-10-25 | Unverified |
| Real-time blur on Android needs `RenderEffect` (API 31+); older devices need a non-blur fallback | Android developer documentation (not fetched) | 2026-10-25 | Unverified |
| [v1.2 | 2026-10-26] Be Vietnam Pro and Roboto Flex are embedded in the board (SIL Open Font License 1.1, per `design/reference/README.md`); no licence fee | `design/reference/dat-banh-tet-ios-android.html` (licence comment at the top), README | 2026-10-26 | High for the board content; licence terms of the font files themselves not re-read from the font projects |
| [v1.2 | 2026-10-26] CSS pixel values of the board map one to one to pt (iOS, 390 x 844 frame) and dp (Android, 412 x 892 frame) | Board frame sizes | 2026-10-26 | High (the board was drawn at device point sizes) |

## 2. Tokens

[v1.2 | 2026-10-26] Values come from the board CSS (`design/reference/screens/*.html`). Board values are exact; "ref" marks are removed. Where the board does not show a value (fallbacks, error colours), the earlier value is kept and marked "not on board". Contrast ratios were estimated by hand and shall be re-measured on built screens.

### 2.1 Color

Backgrounds are a diagonal soft gradient with three blurred colour blobs behind content (section 3, `AppBackground`).

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `color.primary` | Primary button fill, selected state fill, accents | #2F6B3F | #1D6B3A |
| `color.primary.top` | Top of the primary button gradient (iOS only) [v1.2 | 2026-10-26] | #3F8A57 (button fill is a 180 degree gradient from this colour to `color.primary`) | none: flat `color.primary` |
| `color.onPrimary` | Text and icons on primary | #FFFFFF | #FFFFFF |
| `color.primaryContainer` [v1.2 | 2026-10-26] | Round chevron badge, "Edit" pill, weight chip (Android); not used on iOS | not used (selected states are filled `color.primary`) | #A8F0BC |
| `color.onPrimaryContainer` [v1.2 | 2026-10-26] | Text and icons on primary container | not used | #00391A |
| `color.accentText` [v1.2 | 2026-10-26] | Prices, "Edit" link, label on image placeholder | #1F5A33 | `color.primary` (#1D6B3A) for prices; #00391A on placeholders |
| `color.tertiaryContainer` [v1.2 | 2026-10-26] | Second attribute chip on the cake detail (Android) | not used | #FFDF9E with text #3D2E00 |
| `color.background.top` | Gradient start | #E4F0E6 (0%) [v1.2 | 2026-10-26] | #DDF3E2 (0%) [v1.2 | 2026-10-26] |
| `color.background.mid` [v1.2 | 2026-10-26] | Gradient middle stop | none (two stops) | #F3F6E4 (55%) |
| `color.background.bottom` | Gradient end | #F4EEDC (100%) [v1.2 | 2026-10-26] | #FBEFD9 (100%) [v1.2 | 2026-10-26] |
| `color.background.angle` [v1.2 | 2026-10-26] | Gradient direction (CSS angle, 0 = up, clockwise) | 160 degrees | 170 degrees |
| `color.blob.green` [v1.2 | 2026-10-26] | Blob 1, top left | #7FC196 at 75% | #8ED6A3 at 80% |
| `color.blob.amber` [v1.2 | 2026-10-26] | Blob 2, right middle (replaces `color.blob.cream`) | #F2C879 at 70% | #F6D58A at 70% |
| `color.blob.mint` [v1.2 | 2026-10-26] | Blob 3, bottom left | #A6D8C4 at 70% | #A8DCD0 at 70% |
| `color.surface.glass` | Card, bar and control surface (translucent) | White at 52% over blur [v1.2 | 2026-10-26] | #F7FCF4 at 60% over blur [v1.2 | 2026-10-26] |
| `color.surface.stroke` | Hairline edge of glass surfaces | White at 75%, 1 pt [v1.2 | 2026-10-26] | White at 60%, 1 dp [v1.2 | 2026-10-26] |
| `color.surface.highlight` [v1.2 | 2026-10-26] | Inner top edge light of glass (inset 0, 1 pt, 0 blur) | White at 90% | White at 80% |
| `color.surface.chip` [v1.2 | 2026-10-26] | Unselected day, slot, input and info chip fill, with a 1 pt border | White at 60%, border White at 85% | White at 60%, border White at 80% |
| `color.surface.solid` | Fallback when glass or blur is unavailable (not on board) | #FBF8EE | #FBF8EE |
| `color.text.primary` | Body and titles | #14231A [v1.2 | 2026-10-26] (about 14:1 on the gradient, estimate) | #14201A [v1.2 | 2026-10-26] |
| `color.text.secondary` | Descriptions, labels, hints | #3E5045 [v1.2 | 2026-10-26] (about 7:1, estimate) | #3F4A42 [v1.2 | 2026-10-26] |
| `color.text.disabled` | Disabled labels | `color.text.secondary` on `color.disabledFill` [v1.2 | 2026-10-26] | same |
| `color.error` | Error text and field outline (not on board) | #B3261E (about 5.8:1 on cream) | #B3261E |
| `color.errorContainer` | Error banner fill (not on board) | #FBE4E1 | #F9DEDC |
| `color.destructive` [v1.2 | 2026-10-26] | Destructive text on the board (cancel order, sign out; later slices) | #9A3B26 | #9A3B26 |
| `color.warningContainer` | Info or rule hint banner fill (not on board) | #FFF1CC | #FFF1CC |
| `color.disabledFill` | Disabled button fill | Dark ink at 12%: rgba(20,35,26,0.12) [v1.2 | 2026-10-26] | rgba(20,32,26,0.10) [v1.2 | 2026-10-26] |
| `color.divider` [v1.2 | 2026-10-26] | 1 pt separator in summary cards | rgba(20,35,26,0.10) | rgba(20,32,26,0.10) |
| `color.progress.inactive` [v1.2 | 2026-10-26] | Unfilled step segment | rgba(20,35,26,0.15) | rgba(20,32,26,0.12) |
| `color.image.placeholder` [v1.2 | 2026-10-26] | Fill while a cake picture is missing or failed | 145 degree gradient White at 80% to rgba(127,193,150,0.5), 1 pt border White at 80% | 145 degree gradient #CFF7D9 to #8ED6A3, 1 dp border White at 70% (detail hero: 150 degree #CFF7D9 to #6FC58B, no border) |
| `color.focus` | Keyboard and switch-access focus ring (not on board) | #1A56DB | #1A56DB |

The board's property panel offers two other accent colours (#1F4E6B and #9A3B26). They are editor options, not part of the system; the app uses `color.primary` only.

Blob geometry (all blobs are circles with a Gaussian blur; position is the offset of the circle from the screen edge):

| Blob | iOS (390 x 844) | Android (412 x 892) |
| ---- | --------------- | ------------------- |
| `color.blob.green` | 320 x 320, top -60, left -80, blur 70 | 340 x 340, top -80, left -90, blur 80 |
| `color.blob.amber` | 300 x 300, top 380, right -100, blur 80 | 320 x 320, top 420, right -110, blur 90 |
| `color.blob.mint` | 260 x 260, bottom -80, left -40, blur 70 | 280 x 280, bottom -90, left -50, blur 80 |

Positions scale with the screen: iOS offsets are measured from the edges named above, so they hold on other widths. The Android cake detail omits the green blob (the hero picture covers it).

### 2.2 Typography

[v1.2 | 2026-10-26] The board does not use the system fonts. iOS uses Be Vietnam Pro (weights 400, 500, 600, 700). Android uses Roboto Flex (weights 400, 500, 700, 800), with Roboto as the board's fallback. Both are free (SIL Open Font License 1.1) and include full Vietnamese diacritics. Bundling them is a technical question for atlas-architect (TQ-11 in `place-order-ui.md`); until it is answered, the system font (SF Pro, Roboto) with the same size and weight is the fallback and must look acceptable. Sizes below are the board's; they scale with the system text-size setting (iOS Dynamic Type: scale each value relative to the nearest text style; Android: `sp`).

| Token | Purpose | iOS value (Be Vietnam Pro) | Android value (Roboto Flex) |
| ----- | ------- | -------------------------- | --------------------------- |
| `type.display` | Success title, shop name on S-2 | 32 pt, Bold 700, line height 1.15, tracking -0.5 (S-2 shop name: 30 pt, line height 1.15) | 34 sp, ExtraBold 800, line height 1.1, tracking -1 (S-2 shop name: 32 sp, 800, tracking -1) |
| `type.title.large` | Screen title under the back button (S-3, S-5 to S-8) | 34 pt, Bold 700, line height 1.1, tracking -0.5 | 38 sp, ExtraBold 800, line height 1.05, tracking -1.2 |
| `type.title.detail` [v1.2 | 2026-10-26] | Cake name on the detail card | 26 pt, Bold 700, line height 1.15, tracking -0.3 | 30 sp, ExtraBold 800, line height 1.1, tracking -0.8 |
| `type.title.hero` [v1.2 | 2026-10-26] | Title inside a home action card | 22 pt, Bold 700 | 26 sp, Bold 700, tracking -0.5 |
| `type.title.medium` | Card titles, summary total | 17 pt Bold 700 (review total), 18 pt Bold 700 (bar total) | 20 sp ExtraBold 800 (review total and bar total) |
| `type.price.detail` [v1.2 | 2026-10-26] | Price on the cake detail | 18 pt, Bold 700, `color.accentText` | 20 sp, Bold 700, `color.primary` |
| `type.body` | Descriptions, greeting, fields | 15 pt, Regular 400, line height 1.5, `color.text.secondary` (greeting, detail description); input text 16 pt | 15 sp (detail) and 16 sp (greeting), Regular 400, line height 1.5, `color.text.secondary`; input text 16 sp |
| `type.list.name` [v1.2 | 2026-10-26] | Cake name in a list row | 15 pt, SemiBold 600, line height 1.25 | 16 sp (S-3) and 15 sp (S-5), Bold 700, line height 1.25 |
| `type.list.desc` [v1.2 | 2026-10-26] | Cake description in a list row | 12 pt, Regular, line height 1.3, `color.text.secondary` | 13 sp (S-3) and 12 sp (S-5), same line height |
| `type.body.strong` | Prices in rows, totals | 13 pt (S-3) and 12 pt (S-5), Bold 700 / SemiBold 600, `color.accentText` | 14 sp (S-3) and 13 sp (S-5), Bold 700, `color.primary` |
| `type.label` | Buttons | 16 pt, SemiBold 600 (bar button), 15 pt SemiBold (small and disabled button), 14 pt SemiBold (contact pill, "Edit") | 17 sp, Bold 700 (bar button), 15 sp SemiBold (disabled), 14 sp Medium 500 (contact pill) |
| `type.section` [v1.2 | 2026-10-26] | Section label inside a card ("Ngày nhận", "Bánh đã chọn") | 13 pt, SemiBold 600, `color.text.secondary` | 13 sp, Bold 700, `color.text.secondary` |
| `type.chip` [v1.2 | 2026-10-26] | Day, slot and detail chips | 13 pt SemiBold 600 (slot, detail chip); day: weekday 12 pt Medium, number 18 pt Bold | 14 sp SemiBold 600 (detail chip); slot 13 sp SemiBold; day: weekday 12 sp, number 18 sp Bold |
| `type.caption` | Hints, counters, step indicator, field labels | 12 pt Regular (field label, bar total label), 13 pt SemiBold (step label) | 12 sp Regular, 13 sp SemiBold (step label) |
| `type.hero.sub` [v1.2 | 2026-10-26] | Subtitle in a home action card | 13 pt Regular (secondary on the glass card, white at 90% on the green card) | 14 sp Regular (white at 92% on the green card) |

Stepper value: 15 pt Bold 700 (iOS), 16 sp Bold 700 (Android). Success and review body rows: 14 pt / 14 sp, values Bold 700 (success) or SemiBold 600 at 15 pt (iOS review) and Medium 500 at 16 sp (Android review). Admin screens (later slices) use `type.title.large` at 34 pt, list title 18 pt Bold, status badge 11 pt Bold.

All text scales with the system setting (iOS up to the largest accessibility size; Android up to 200% font scale).

### 2.3 Spacing

4-point grid. [v1.2 | 2026-10-26] The board has two horizontal margins: 16 pt (iOS) or 12 dp (Android) for cards and bars (they sit close to the screen edge so the glass reads as floating), and 24 pt / 16 dp for headings and plain text. The earlier single 20 margin is removed.

| Token | iOS | Android |
| ----- | --- | ------- |
| `space.xs` | 4 pt | 4 dp |
| `space.sm` | 8 pt | 8 dp |
| `space.md` | 12 pt | 12 dp |
| `space.lg` | 16 pt | 16 dp |
| `space.xl` | 24 pt | 24 dp |
| `space.xxl` | 32 pt | 32 dp |
| `space.screenMargin` | 16 pt (cards, bars) [v1.2 | 2026-10-26] | 12 dp (cards, bars) [v1.2 | 2026-10-26] |
| `space.textMargin` [v1.2 | 2026-10-26] | 24 pt (headings, plain text, back button) | 16 dp |
| `space.cardGap` [v1.2 | 2026-10-26] | 12 pt between list cards, 14 pt between hero cards and between form cards | 12 dp |
| `space.cardPadding` [v1.2 | 2026-10-26] | 12 pt (list rows), 16 to 18 pt (form and summary cards), 20 pt (cake detail card) | 12 to 16 dp (rows), 16 to 20 dp (forms and summaries), 22 dp (detail card) |
| `space.barInset` [v1.2 | 2026-10-26] | Bar: 16 pt from the sides, 28 pt from the bottom edge, 14 pt inner padding | Bar: 12 dp from the sides, 20 dp from the bottom edge, 12 to 14 dp inner padding |
| `size.touchTarget` | 44 pt minimum | 48 dp minimum |
| `size.buttonHeight` | 52 pt (bar button) [v1.2 | 2026-10-26] | 56 dp (bar button) |
| `size.thumb` | 84 pt square (S-3), 68 pt (S-5) [v1.2 | 2026-10-26] | 84 dp square (S-3), 64 dp (S-5) [v1.2 | 2026-10-26] |
| `size.backButton` [v1.2 | 2026-10-26] | 44 pt circle | 48 dp circle |
| `size.heroCard` [v1.2 | 2026-10-26] | 132 pt high | 140 dp high |
| `size.contactButton` [v1.2 | 2026-10-26] | 56 pt high, capsule | 60 dp high, capsule |
| `size.logo` [v1.2 | 2026-10-26] | Large 132 pt (icon 76), Small 72 pt (icon 42), admin 80 pt (icon 46) | Large 168 dp (icon 96), Small 88 dp (icon 52) |
| `size.heroImage` [v1.2 | 2026-10-26] | 330 pt high card inset 16 pt, top 56 pt | 400 dp high, full width, from the top edge |
| `size.stepper` [v1.2 | 2026-10-26] | Capsule 2 pt padding, two 44 pt round buttons around the value | 2 dp padding, two 44 dp round buttons around the value |
| `size.stepSegment` [v1.2 | 2026-10-26] | 22 x 5 pt, radius 3, gap 4 | Segments share the width, 8 dp high, radius 4, gap 4 |

### 2.4 Radius

| Token | iOS | Android |
| ----- | --- | ------- |
| `radius.card` | 28 pt (list rows, form and summary cards) [v1.2 | 2026-10-26] | 32 dp (list rows, form cards), 36 dp (review cards) [v1.2 | 2026-10-26] |
| `radius.hero` [v1.2 | 2026-10-26] | 36 pt (home action cards, hero image) | 44 dp, with one corner at 16 dp: "View products" card has the bottom left corner at 16, "Place order" card has the top left corner at 16 |
| `radius.detail` [v1.2 | 2026-10-26] | 32 pt (cake detail card) | 40 dp |
| `radius.bar` [v1.2 | 2026-10-26] | 36 pt | 40 dp |
| `radius.pill` | Capsule (button height / 2: 26 pt bar button, 28 pt contact pill, 22 pt step indicator and slot chip) [v1.2 | 2026-10-26] | Full (stadium) |
| `radius.field` | Capsule: 23 pt on a 46 pt field [v1.2 | 2026-10-26] | Capsule: 24 dp on a 48 dp field |
| `radius.image` | 20 pt (list thumbnail) | 24 dp (S-3 thumbnail), 22 dp (S-5 thumbnail) |
| `radius.heroImage` [v1.2 | 2026-10-26] | 36 pt on all corners | 0 on the top, 56 dp on the bottom corners |
| `radius.chip` [v1.2 | 2026-10-26] | 18 pt (detail chip), 20 pt (day chip) | 20 dp (40 dp high chip), 22 dp (day chip) |
| `radius.logo` | Large 40 pt, Small 24 pt, admin 26 pt (rounded square) [v1.2 | 2026-10-26] | Organic blob: `border-radius: 58% 42% 54% 46% / 46% 56% 44% 54%` (a fixed asymmetric shape; draw as a path) [v1.2 | 2026-10-26] |

### 2.5 Elevation and material

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `elevation.card` | Glass cards, bars, back button | Liquid Glass regular. Board glass: fill `color.surface.glass`, backdrop blur 24 with saturation 180%, stroke `color.surface.stroke`, shadow 0 / 8 / blur 32 rgba(30,70,45,0.12), inner highlight [v1.2 | 2026-10-26] | Translucent tonal fill. Board glass: fill `color.surface.glass`, backdrop blur 28 with saturation 170%, stroke, shadow 0 / 8 / blur 28 rgba(20,60,35,0.10), inner highlight; real blur on API 31+ only, see fallbacks [v1.2 | 2026-10-26] |
| `elevation.primaryButton` [v1.2 | 2026-10-26] | Shadow under a filled primary button | Hero card: 0 / 10 / blur 24 rgba(47,107,63,0.35); bar button: 0 / 6 / blur 16 same colour; both with inner top highlight White at 45% | Hero card: 0 / 14 / blur 32 rgba(29,107,58,0.35) with inner highlight White at 30%; bar button: inner highlight White at 30%, no outer shadow |
| `elevation.bar` | Floating bottom action bar | Liquid Glass regular, floats 28 pt above the bottom edge [v1.2 | 2026-10-26] | Floating toolbar or `fx` glass bar, floats 20 dp above the bottom edge [v1.2 | 2026-10-26] |
| `elevation.logo` [v1.2 | 2026-10-26] | Android logo blob | not used (glass logo) | 0 / 12 / blur 40 rgba(20,60,35,0.15) (launch), 0 / 12 / blur 32 (success mark), inner highlight White at 80% |
| `elevation.sheet` | Sheets, pickers | System sheet material | Modal bottom sheet, tonal level 1 |
| `material.fallback` | Glass fallback [v1.1 | 2026-10-25] (iOS 17 to 25; Android 8.0 to 11 and any version with reduced transparency) | `Material` (ultra thin) over `color.surface.solid`, hairline `color.surface.stroke` | `color.surface.solid` at 94% without blur (opaque card) |

### 2.6 Motion

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `motion.duration.short` | Taps, toggles | 150 ms | 150 ms |
| `motion.duration.medium` | Appear, error message | 250 ms | 250 ms |
| `motion.duration.long` | Screen transitions, launch exit | 400 ms | 400 ms |
| `motion.spring.standard` | Default movement | Spring, response 0.4, damping 0.85 | Expressive spatial spring, medium stiffness, damping ratio about 0.8 (unverified) |
| `motion.spring.bouncy` | Confirmation emphasis | Spring, response 0.5, damping 0.65 | Expressive spatial spring, low stiffness, damping ratio about 0.6 (unverified) |
| `motion.reduced` | When Reduce Motion or "remove animations" is on | Cross-fade 150 ms, no blobs drift | Cross-fade 150 ms, no blobs drift |

The board is static (no animation values); motion tokens are unchanged.

### 2.7 Iconography [v1.2 | 2026-10-26]

The board draws every icon as an inline line icon on a 24 x 24 grid: stroke only, no fill, round caps and joins, stroke width 2.0 to 2.4. The set is small. Map each to the native symbol set with the same meaning and weight (SF Symbols medium weight; Material Symbols Rounded, weight 400 to 500, optical size 24); do not draw bitmap icons.

| Icon | Used for | Board size iOS / Android | Board stroke | SF Symbol (indicative) | Material Symbol (indicative) |
| ---- | -------- | ------------------------ | ------------ | ---------------------- | ---------------------------- |
| Chevron right | Home action cards, list row end, settings row | 26 pt (home), 20 pt (list), 18 pt (settings) / 26 dp, 20 dp | 2.2 (iOS), 2.4 (Android) | `chevron.right` | `chevron_right` |
| Chevron left | Back button (iOS) | 20 pt | 2.2 | `chevron.left` | n/a |
| Arrow left | Back button (Android) | 24 dp | 2.2 | n/a | `arrow_back` |
| Chat bubble | Zalo button (generic icon, ADR-0015) | 18 pt / 20 dp | 2 | `message` | `chat_bubble` |
| Phone | Phone button | 18 pt / 20 dp (16 pt in the admin "call customer" button) | 2 to 2.2 | `phone` | `call` |
| Check | Success mark | 46 pt in a 96 pt glass circle / 58 dp in a 120 dp blob | 2.2 / 2.4 | `checkmark` | `check` |
| Minus and plus | Stepper | text glyphs "−" and "+", 20 pt / 22 dp | n/a | `minus`, `plus` | `remove`, `add` |
| List and gear | Admin tab bar (later slices) | 22 pt | 2 | `list.bullet`, `gearshape` | `list`, `settings` |

Icon colour follows the text colour of its container (`color.text.primary`, `color.onPrimary` on primary, `color.text.secondary` for list chevrons). Logo mark: the board draws one mark for the launch screen, home and admin sign-in: a rounded log (rectangle 48 x 20, corner radius 10) rotated -20 degrees with three slanted tie lines, stroke 3 on a 64 x 64 grid, in `color.primary`. Treat it as the placeholder artwork until the owner confirms (BQ-1 in `place-order-ui.md`).

### 2.8 Component styles taken from the board [v1.2 | 2026-10-26]

| Style | iOS | Android |
| ----- | --- | ------- |
| Glass card | `color.surface.glass` fill, blur, stroke, highlight, `elevation.card` shadow (section 2.5) | Same pattern with Android values |
| Primary button | 180 degree gradient `color.primary.top` to `color.primary`, white label, `elevation.primaryButton` | Flat `color.primary`, white label, inner highlight |
| Secondary (glass) button | Glass fill, `color.text.primary` label | Glass fill (contact pills) or `color.surface.chip` |
| Disabled button | `color.disabledFill`, `color.text.secondary` label, no shadow | Same |
| Selected chip (day, slot, tab) | Fill `color.primary`, border `color.primary`, white label, shadow 0 / 4 / blur 12 rgba(47,107,63,0.30) with inner highlight White at 40% | Fill `color.primary`, border `color.primary`, white label, no shadow |
| Unselected chip | `color.surface.chip` with border | Same |
| Stepper | Glass capsule with a 2 pt padding; both buttons transparent, `color.text.primary` glyph | Capsule filled rgba(20,32,26,0.06); minus button transparent; plus button filled `color.primary` with a white glyph |
| Step indicator | Glass capsule: three 22 x 5 segments (filled `color.primary`, rest `color.progress.inactive`) and the label "Bước n/3" | Glass capsule 48 dp high beside the back button: segments share the width (8 dp high) and the label "n/3" |
| Text field | 46 pt high capsule, 16 pt horizontal padding, fill `color.surface.chip` with border, label above in `type.caption` | 48 dp high capsule, 18 dp horizontal padding, same fill |
| Info chip (detail) | Neutral `color.surface.chip`, 8 / 14 pt padding | `color.primaryContainer` and `color.tertiaryContainer` fills, 40 dp high |
| Success mark | 96 pt glass circle with check | 120 dp blob (`color.primaryContainer`) with check |
| Tab bar (admin, later slices) | Floating glass pill 40 pt from the sides, two tabs 56 pt high, selected tab filled with the primary gradient | Not extracted |

## 3. Components

Platform mapping column gives the native building block (names are indicative; the developer confirms against the SDK at build time).

| Component | Purpose | Variants | States | iOS mapping | Android mapping |
| --------- | ------- | -------- | ------ | ----------- | --------------- |
| `AppBackground` | Gradient with three blurred blobs behind every screen [v1.2 | 2026-10-26] | One | Static; blobs still when `motion.reduced` | SwiftUI gradient (`color.background.*`, angle 160) plus three blurred circles (`color.blob.*`, section 2.1 geometry) | Compose gradient (three stops, angle 170) plus three blurred circles; blur by `RenderEffect` on API 31+, flat radial gradients below |
| `LogoMark` | Shop logo | Large (launch), Small (home) | Static | Glass rounded square (`radius.logo`, `size.logo`) holding the mark | Blob shape filled `color.primaryContainer` with a white-edged border (`radius.logo`, `size.logo`) |
| `TopBar` [v1.2 | 2026-10-26] | Back control and screen title | Large title with a floating back button (S-3, S-5 to S-8); floating back button over the picture only (S-4); no title bar (S-1, S-2, S-9) | Default | The board does not use a native navigation bar: a round glass back button (`size.backButton`) sits at the top left, the large title (`type.title.large`) sits below it on the next line, both on the background. Build with a hidden native bar and a custom header, keeping swipe-back | Same layout: round glass back button, large title below; system and predictive back stay active |
| `GlassCard` | Container for grouped content | Static, Tappable | Default, Pressed, Disabled | `glassEffect` in a rounded rectangle (`radius.card`) inside `GlassEffectContainer`; fallback `material.fallback` | Surface with `radius.card`, glass fill, blur if available |
| `BottomActionBar` | Floating glass bar holding the screen's primary action (and, on S-5, the running total) [v1.2 | 2026-10-26] | One button; button with total on the left (S-5); two buttons side by side only for the admin | Default, Disabled action, Loading action | Floating Liquid Glass bar (`radius.bar`, `space.barInset`) | Floating glass bar (`radius.bar`, `space.barInset`); flexible bottom app bar or floating toolbar if the M3 Expressive component can be styled to match, otherwise a custom surface |
| `HeroActionCard` [v1.2 | 2026-10-26] | Large tappable card on the home screen | Glass (View products), Primary (Place order) | Default, Pressed, Disabled (dimmed) | Card `size.heroCard` high, title `type.title.hero`, subtitle, chevron; glass or primary gradient fill | Same on Android with the asymmetric corners of `radius.hero` and a 52 dp round chevron badge (`color.primaryContainer` on glass, 22% white on primary) |
| `PrimaryButton` | Main action | Full width | Default, Pressed, Disabled, Loading | Filled capsule with the primary gradient (`size.buttonHeight`), white label; prominent glass style where it matches | Filled stadium button, `color.primary`, `size.buttonHeight` |
| `SecondaryButton` | Alternative action | Full width | Default, Pressed, Disabled | Glass capsule (non-prominent) | Tonal or glass capsule |
| `ContactButton` | Zalo or phone shortcut | Zalo (generic chat icon, then the word "Zalo", then the shop's Zalo number when known; no brand mark, ADR-0015) [v1.1 | 2026-10-25] [v1.2 | 2026-10-26], Phone (phone icon then the shop number) | Default, Pressed, Disabled | Two equal glass capsules side by side in the bottom bar area (`size.contactButton`); `material.fallback` on iOS 17 to 25 | Same on Android; glass capsule, not a tonal `ButtonGroup` button [v1.2 | 2026-10-26] |
| `ProductCard` | Product in list | List row: `size.thumb` image, name, description (two lines max), price, trailing chevron [v1.2 | 2026-10-26] | Default, Pressed, Loading (skeleton), Image failed | `GlassCard` tappable, `radius.image` thumbnail, bare chevron | `GlassCard` tappable, `radius.image` thumbnail, chevron inside a 40 dp round `color.primaryContainer` badge |
| `QuantityStepper` limits | [v1.1 | 2026-10-25] Value from 0 to 99; plus disabled at 99 with no message | | | | |
| `QuantityStepper` | Choose quantity 0 and up | Minus, value, plus | Default, Min (minus disabled at 0), Pressed | Glass capsule with two 44 pt buttons; value is a label (section 2.8) | Capsule with minus and a filled plus button around the value (section 2.8) |
| `StepIndicator` | "Bước n/3" on the board; "Step n of 4" in the approved PRD (see BQ-2 in `place-order-ui.md`) [v1.2 | 2026-10-26] | Segments plus label | Current, done | Glass capsule with three 22 x 5 segments and a label, placed beside the back button | Glass capsule 48 dp high beside the back button, segments share the width |
| `DateGrid` | Month calendar for date choice (approved PRD) | Month header with previous and next; day cells | Day: Available, Selected, Unavailable (full or out of range), Today marker | Custom grid (the system graphical date picker cannot mark capacity-based dates unavailable: unverified, confirm) | Custom grid (same reason) |
| `DayChipRow` [v1.2 | 2026-10-26] | The board's date choice: five day chips in a row (weekday, day number) for the next five days | Chip: Default, Selected, Unavailable | One row of five equal chips, 62 pt minimum height, `radius.chip` | One row of five equal chips, 64 dp minimum height |
| `SlotChip` | Delivery time slot | Single-select chip. The board shows three chips in a row (labels like "7:00–10:00"); the approved spec uses a vertical list | Default, Selected, Disabled | Capsule 44 pt high, selected = filled `color.primary` | Capsule 44 dp high, selected = filled `color.primary` |
| `TextField` | Single-line text | Text, Phone, Multiline (note) | Default, Focused, Filled, Error, Disabled | Capsule field (section 2.8), label above | Capsule field (section 2.8), label above |
| `PickerField` | Choose district | Opens list | Default, Selected, Error, Loading, Disabled | Field opening a sheet list (or menu) | Exposed dropdown or modal bottom sheet list |
| `SummaryRow` | Label and value on review | Text value, Money value, Multiline value, Total (emphasized) | Default | HStack in `GlassCard`, divider `color.divider` before the money rows | Row in `GlassCard` |
| `InlineMessage` | Message near a control or at the top of a section | Error, Info | Visible, hidden | Icon plus text on `color.errorContainer` or `color.warningContainer` | Same |
| `NoticeText` | Short privacy sentence | One | Default | `type.caption` text | `type.caption` text |
| `OrderCodeDisplay` | Large order code | One | Default | Selectable text, `type.display` | Selectable text, `type.display` |
| `StateView` | Full-area loading, empty or error | Loading (skeleton or spinner), Empty, Error with retry | Loading, Empty, Error | Skeleton placeholders; error uses icon, text, `SecondaryButton` | Expressive `LoadingIndicator`; same layout |
| `Toast` | Short non-blocking notice (cannot open Zalo or dialer) | One | Shown 4 s | Glass capsule at top | Snackbar above the bar |
| `StatusMark` | Success mark on confirmation | One | Animated, static | 96 pt glass circle with an SF Symbol checkmark and bounce effect | 120 dp blob with an animated vector check |
| `InfoChip` [v1.2 | 2026-10-26] | Short fact chip on the cake detail (board: weight, shelf life; not in the approved PRD, see BQ-3) | Neutral, Primary container, Tertiary container | Neutral `color.surface.chip` | `color.primaryContainer`, `color.tertiaryContainer` |

Fallbacks for older systems:

- [v1.1 | 2026-10-25] Minimum versions (owner decision, ADR-0005): iOS 17 and Android 8.0 (API 26).
- iOS 17 to 25 (before Liquid Glass): `GlassCard` and `BottomActionBar` render with `material.fallback` (system material blur over `color.surface.solid`, hairline stroke); `PrimaryButton` is a filled capsule in `color.primary`, `SecondaryButton` and `ContactButton` are material capsules; no glass morphing between shapes. Layout and sizes stay identical. iOS 26 and later: Liquid Glass.
- Android 12 (API 31) and later: translucent glass cards over natively blurred background blobs. Android 8.0 to 11 (API 26 to 30): opaque cards and bar with `color.surface.solid` at 94%, no blur, blobs as flat soft gradients, same layout. No paid or third-party blur library (ADR-0012).
- Reduce Transparency, Increase Contrast, remove animations or high-contrast text on any version: `material.fallback`.
- [v1.2 | 2026-10-26] The board relies on `backdrop-filter` blur on every glass surface. The iOS 17 to 25 fallback (system material) approximates it; the glass fill and stroke values of section 2.1 apply on top of the material so the look stays close to the board.

## 4. Motion & Haptics

| Event | Motion | iOS haptic | Android haptic |
| ----- | ------ | ---------- | -------------- |
| Push or pop screen | Native navigation transition, `motion.duration.long`; Android uses shared-axis or predictive back | None | None |
| Bar action pressed | Scale to 0.97 with `motion.spring.standard` | Light impact | Context click (virtual key) |
| Quantity changed | Value cross-fade `motion.duration.short` | Selection | Segment tick |
| Date or slot selected | Fill change `motion.duration.short` | Selection | Context click |
| Blocked action or validation failure | Message appears with `motion.duration.medium`; field shakes 4 pt once (skipped under `motion.reduced`) | Notification error | Reject |
| Order confirmed | `StatusMark` plays with `motion.spring.bouncy` | Notification success | Confirm |
| Order not sent | Banner slides in | Notification error | Reject |

Haptic names are indicative of native feedback generators (UIKit feedback generators; Compose `HapticFeedbackType`); exact constants are unverified and are confirmed at build time.

## 5. Accessibility

Defaults from `docs/process/standards/02-ui.md`:

- Touch target at least `size.touchTarget` (44 pt iOS, 48 dp Android), including stepper buttons and calendar day cells.
- Text contrast at least 4.5:1; large text and icons at least 3:1. Text over glass uses `color.text.primary` on `color.surface.glass`; if contrast over a blob cannot be assured, the surface falls back to `color.surface.solid`. [v1.2 | 2026-10-26] Contrast to re-measure on built screens: white label on `color.primary.top` (#3F8A57, the lighter end of the button gradient, estimated about 4.4:1 and therefore the weak point; the label is 16 pt Semibold, so confirm 4.5:1 or darken the top stop), `color.text.secondary` on glass over the amber blob, `color.accentText` prices on glass.
- Every icon-only control has a text label for screen readers (the board gives the back button `aria-label` "Quay lại ...").
- Layout survives the largest text size: content scrolls vertically, rows wrap, nothing truncates a price, quantity, or message. [v1.2 | 2026-10-26] The board uses fixed heights for home action cards (132 / 140) and bar buttons; at large text they grow in height instead of clipping.
- State is never signalled by colour alone (unavailable dates also carry a text label for screen readers and a pattern, such as a diagonal strike, in the visual).
- Reduce Motion, Reduce Transparency and Increase Contrast (iOS) and remove-animations and high-contrast text (Android) are honoured through `motion.reduced` and `material.fallback`.

Component specifics are in the feature document.

## 6. Open Questions

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| DS-Q1 | Minimum iOS and Android versions (Liquid Glass needs iOS 26; Material 3 Expressive depends on the Compose Material3 release) | Decides how much of the fallback is built | No | technical | Closed [v1.1 | 2026-10-25] | iOS 17 and Android 8.0 (API 26), owner decision; ADR-0005 |
| DS-Q2 | Is paid or third-party UI tooling allowed (for example a blur library for Android below API 31)? | Fallback cost | No | technical | Closed [v1.1 | 2026-10-25] | No; native only (ADR-0012) |
| DS-Q3 | [v1.2 | 2026-10-26] Bundle Be Vietnam Pro (iOS) and Roboto Flex (Android) as app resources, as the board uses them? Variable or static font files, app size, text scaling with custom fonts, fallback to system fonts | Section 2.2; same question as TQ-11 in `place-order-ui.md`, for atlas-architect | No | technical | Open | Proposed: yes (free licence); fall back to the system font if a file is missing |

## 7. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version created with the place-order feature. |
| 1.1 | 2026-10-25 | Minimum OS versions fixed (iOS 17, Android 8.0) and fallbacks defined per level; `material.fallback` applicability; `ContactButton` Zalo uses generic icon plus word; stepper range 0 to 99; DS-Q1 and DS-Q2 closed. |
| 1.2 | 2026-10-26 | Reconciled with the owner's design board (`design/reference`): exact palette, background gradients and the three blobs per platform, glass values, typography (Be Vietnam Pro and Roboto Flex with the board's sizes, weights and tracking), radii, spacing margins and sizes, shadows, iconography, component styles; new tokens and components (`HeroActionCard`, `DayChipRow`, `InfoChip`, `color.accentText`, `color.primary.top`, `color.tertiaryContainer`, `color.destructive`, size and radius tokens); `TopBar` now a custom header; removed the earlier "ref" values and the system-font assumption; DS-Q3 opened; contrast watch-list. |
