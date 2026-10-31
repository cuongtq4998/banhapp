# Design System, part 2: Color tokens (sections 2, 2.1)

[v1.3 | 2026-10-27] Part of the split design system; index: [design-system.md](../design-system.md). Content unchanged from v1.2; section numbers are the original ones. Code comments cite this part as "design-system.md section 2.1".

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
