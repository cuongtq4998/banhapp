# Design System, part 3: Typography, spacing, radius tokens (sections 2.2 to 2.4)

[v1.3 | 2026-10-27] Part of the split design system; index: [design-system.md](../design-system.md). Content unchanged from v1.2; section numbers are the original ones. Code comments cite this part as "design-system.md sections 2.2, 2.3 and 2.4".

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
